defmodule Smile.Decoder do
  @moduledoc """
  Provides functionality to decode Smile binary format into Elixir terms.

  The decoder parses Smile-encoded binary data and reconstructs the original
  Elixir data structures. It handles all token types defined in the Smile
  specification and maintains back-reference tables for shared names and values.

  ## Decoding Process

  The decoder performs the following steps:

    1. Parse and validate the 4-byte Smile header
    2. Extract header flags (shared names, shared values, raw binary)
    3. Initialize decoding state with appropriate back-reference tables
    4. Parse tokens and recursively decode values
    5. Maintain back-reference lists for shared names and values

  ## Supported Output Types

  The decoder produces the following Elixir types:

    * Smile null → `nil`
    * Smile boolean → `true` or `false`
    * Smile integer → Elixir integer
    * Smile float → Elixir float
    * Smile string → Binary string
    * Smile array → Elixir list
    * Smile object → Elixir map with string keys

  ## Error Handling

  The decoder returns descriptive errors for various failure scenarios:

    * `:invalid_header` - Invalid or missing Smile header
    * `:incomplete_string` - String data is truncated
    * `:incomplete_int32` / `:incomplete_int64` - Integer data is truncated
    * `:incomplete_float32` / `:incomplete_float64` - Float data is truncated
    * `:missing_string_terminator` - Long string missing end marker
    * `{:unknown_token, byte}` - Unrecognized token byte
    * `{:invalid_shared_reference, index}` - Invalid back-reference index

  ## Examples

      # Basic decoding
      iex> binary = <<58, 41, 10, 3, 33>>  # Smile null
      iex> Smile.Decoder.decode(binary)
      {:ok, nil}

      # Decoding with error
      iex> Smile.Decoder.decode(<<1, 2, 3>>)
      {:error, :invalid_header}

  ## Implementation Details

  The decoder implements:

    * Header validation with version and flag parsing
    * Token-based parsing with pattern matching
    * Back-reference management for shared names and values (up to 1024 entries each)
    * Variable-length integer decoding (VInt)
    * ZigZag decoding for signed integers
    * Recursive decoding for nested structures (arrays and objects)
  """

  import Bitwise
  alias Smile.Constants, as: C

  @doc """
  Decodes Smile binary format into an Elixir term.

  ## Examples

      iex> Smile.Decoder.decode(<<0x3A, 0x29, 0x0A, 0x03, 0xFA, ...>>)
      {:ok, %{"hello" => "world"}}
  """
  def decode(binary) when is_binary(binary) do
    case parse_header(binary) do
      {:ok, header, rest} ->
        state = %{
          shared_names: header.shared_names,
          shared_values: header.shared_values,
          raw_binary: header.raw_binary,
          name_list: [],
          value_list: []
        }

        case decode_value(rest, state) do
          {:ok, value, _rest, _state} -> {:ok, value}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Parse Smile header
  defp parse_header(<<0x3A::8, 0x29::8, 0x0A::8, flags::8, rest::binary>>) do
    header = %{
      shared_names: (flags &&& C.header_bit_has_shared_names()) != 0,
      shared_values: (flags &&& C.header_bit_has_shared_string_values()) != 0,
      raw_binary: (flags &&& C.header_bit_has_raw_binary()) != 0
    }

    {:ok, header, rest}
  end

  defp parse_header(_) do
    {:error, :invalid_header}
  end

  # Decode values based on token type
  defp decode_value(<<token::8, rest::binary>>, state) do
    cond do
      # Literals
      token == C.token_literal_null() ->
        {:ok, nil, rest, state}

      token == C.token_literal_true() ->
        {:ok, true, rest, state}

      token == C.token_literal_false() ->
        {:ok, false, rest, state}

      token == C.token_literal_empty_string() ->
        {:ok, "", rest, state}

      # Start of array
      token == C.token_literal_start_array() ->
        decode_array(rest, state)

      # Start of object
      token == C.token_literal_start_object() ->
        decode_object(rest, state)

      # Small integers (-16 to +15)
      (token &&& 0xE0) == C.token_prefix_small_int() ->
        value = decode_small_int(token)
        {:ok, value, rest, state}

      # 32-bit integers
      token == C.token_byte_int_32() ->
        decode_int32(rest, state)

      # 64-bit integers
      token == C.token_byte_int_64() ->
        decode_int64(rest, state)

      # 64-bit floats
      token == C.token_byte_float_64() ->
        decode_float64(rest, state)

      # 32-bit floats
      token == C.token_byte_float_32() ->
        decode_float32(rest, state)

      # Tiny ASCII strings (1-32 bytes)
      (token &&& 0xE0) == C.token_prefix_tiny_ascii() ->
        len = (token &&& 0x1F) + 1
        decode_string_bytes(rest, len, state)

      # Small ASCII strings (33-64 bytes)
      (token &&& 0xE0) == C.token_prefix_small_ascii() ->
        len = (token &&& 0x1F) + 33
        decode_string_bytes(rest, len, state)

      # Tiny Unicode strings (2-33 bytes)
      (token &&& 0xE0) == C.token_prefix_tiny_unicode() ->
        len = (token &&& 0x1F) + 2
        decode_string_bytes(rest, len, state)

      # Short Unicode strings (34-64 bytes)
      (token &&& 0xE0) == C.token_prefix_short_unicode() ->
        len = (token &&& 0x1F) + 34
        decode_string_bytes(rest, len, state)

      # Long ASCII strings
      token == C.token_misc_long_text_ascii() ->
        decode_long_string(rest, state)

      # Long Unicode strings
      token == C.token_misc_long_text_unicode() ->
        decode_long_string(rest, state)

      # Shared string references
      (token &&& 0xE0) == C.token_prefix_shared_string_short() and token > 0 ->
        index = (token &&& 0x1F) - 1
        get_shared_string(index, rest, state)

      token == C.token_prefix_shared_string_long() ->
        decode_long_shared_string(rest, state)

      true ->
        {:error, {:unknown_token, token}}
    end
  end

  defp decode_value(<<>>, _state) do
    {:error, :unexpected_end_of_input}
  end

  # Decode small integers
  defp decode_small_int(token) do
    value = token &&& 0x1F
    # Convert from unsigned to signed
    if value > 15, do: value - 32, else: value
  end

  # Decode 32-bit integers
  defp decode_int32(<<zigzag::32-big, rest::binary>>, state) do
    value = decode_zigzag(zigzag, 32)
    {:ok, value, rest, state}
  end

  defp decode_int32(_rest, _state) do
    {:error, :incomplete_int32}
  end

  # Decode 64-bit integers
  defp decode_int64(<<zigzag::64-big, rest::binary>>, state) do
    value = decode_zigzag(zigzag, 64)
    {:ok, value, rest, state}
  end

  defp decode_int64(_rest, _state) do
    {:error, :incomplete_int64}
  end

  # ZigZag decoding
  defp decode_zigzag(value, bits) do
    max = :math.pow(2, bits) |> trunc()

    # Handle as unsigned
    unsigned = if value < 0, do: value + max, else: value

    if rem(unsigned, 2) == 0 do
      div(unsigned, 2)
    else
      -div(unsigned + 1, 2)
    end
  end

  # Decode 32-bit floats
  defp decode_float32(<<value::float-32-big, rest::binary>>, state) do
    {:ok, value, rest, state}
  end

  defp decode_float32(_rest, _state) do
    {:error, :incomplete_float32}
  end

  # Decode 64-bit floats
  defp decode_float64(<<value::float-64-big, rest::binary>>, state) do
    {:ok, value, rest, state}
  end

  defp decode_float64(_rest, _state) do
    {:error, :incomplete_float64}
  end

  # Decode string bytes
  defp decode_string_bytes(binary, len, state) when byte_size(binary) >= len do
    <<str_bytes::binary-size(len), rest::binary>> = binary

    # Add to shared values if enabled
    new_state =
      if state.shared_values and len <= C.max_short_value_string_bytes() do
        add_shared_value(str_bytes, state)
      else
        state
      end

    {:ok, str_bytes, rest, new_state}
  end

  defp decode_string_bytes(_binary, _len, _state) do
    {:error, :incomplete_string}
  end

  # Decode long strings (with variable length and terminator)
  defp decode_long_string(binary, state) do
    case decode_vint(binary) do
      {:ok, _length, rest} ->
        # Find the string terminator
        case :binary.split(rest, <<C.byte_marker_end_of_string()::8>>) do
          [str_bytes, rest2] ->
            new_state =
              if state.shared_values and byte_size(str_bytes) <= C.max_short_value_string_bytes() do
                add_shared_value(str_bytes, state)
              else
                state
              end

            {:ok, str_bytes, rest2, new_state}

          _ ->
            {:error, :missing_string_terminator}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Decode shared string reference
  defp get_shared_string(index, rest, state) do
    case Enum.at(state.value_list, index) do
      nil -> {:error, {:invalid_shared_reference, index}}
      value -> {:ok, value, rest, state}
    end
  end

  defp decode_long_shared_string(<<offset::8, rest::binary>>, state) do
    index = offset + 31
    get_shared_string(index, rest, state)
  end

  defp decode_long_shared_string(_rest, _state) do
    {:error, :incomplete_shared_reference}
  end

  # Add shared value to state
  defp add_shared_value(value, state) do
    if length(state.value_list) < C.max_shared_string_values() do
      %{state | value_list: state.value_list ++ [value]}
    else
      state
    end
  end

  # Decode arrays
  defp decode_array(binary, state) do
    decode_array_items(binary, [], state)
  end

  defp decode_array_items(<<0xF9::8, rest::binary>>, items, state) do
    {:ok, Enum.reverse(items), rest, state}
  end

  defp decode_array_items(binary, items, state) do
    case decode_value(binary, state) do
      {:ok, value, rest, new_state} ->
        decode_array_items(rest, [value | items], new_state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Decode objects
  defp decode_object(binary, state) do
    decode_object_items(binary, %{}, state)
  end

  defp decode_object_items(<<0xFB::8, rest::binary>>, obj, state) do
    {:ok, obj, rest, state}
  end

  defp decode_object_items(binary, obj, state) do
    case decode_field_name(binary, state) do
      {:ok, key, rest1, new_state1} ->
        case decode_value(rest1, new_state1) do
          {:ok, value, rest2, new_state2} ->
            decode_object_items(rest2, Map.put(obj, key, value), new_state2)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Decode field names
  defp decode_field_name(<<token::8, rest::binary>>, state) do
    cond do
      # Empty string key
      token == C.token_key_empty_string() ->
        {:ok, "", rest, state}

      # Short shared reference
      (token &&& 0xC0) == C.token_prefix_key_shared_short() ->
        index = token &&& 0x3F
        get_shared_name(index, rest, state)

      # Long shared reference
      token == C.token_prefix_key_shared_long() ->
        decode_long_shared_name(rest, state)

      # ASCII key (1-56 bytes)
      (token &&& 0xC0) == C.token_prefix_key_ascii() ->
        len = (token &&& 0x3F) + 1
        decode_field_name_bytes(rest, len, state)

      # Unicode key (1-56 bytes)
      (token &&& 0xC0) == C.token_prefix_key_unicode() ->
        len = (token &&& 0x3F) + 1
        decode_field_name_bytes(rest, len, state)

      # Long key string
      token == C.token_key_long_string() ->
        decode_long_field_name(rest, state)

      true ->
        {:error, {:unknown_key_token, token}}
    end
  end

  # Decode field name bytes
  defp decode_field_name_bytes(binary, len, state) when byte_size(binary) >= len do
    <<name_bytes::binary-size(len), rest::binary>> = binary

    # Add to shared names if enabled
    new_state =
      if state.shared_names do
        add_shared_name(name_bytes, state)
      else
        state
      end

    {:ok, name_bytes, rest, new_state}
  end

  defp decode_field_name_bytes(_binary, _len, _state) do
    {:error, :incomplete_field_name}
  end

  # Decode long field name
  defp decode_long_field_name(binary, state) do
    case decode_vint(binary) do
      {:ok, _length, rest} ->
        case :binary.split(rest, <<C.byte_marker_end_of_string()::8>>) do
          [name_bytes, rest2] ->
            new_state =
              if state.shared_names do
                add_shared_name(name_bytes, state)
              else
                state
              end

            {:ok, name_bytes, rest2, new_state}

          _ ->
            {:error, :missing_field_name_terminator}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get shared name
  defp get_shared_name(index, rest, state) do
    case Enum.at(state.name_list, index) do
      nil -> {:error, {:invalid_shared_name_reference, index}}
      name -> {:ok, name, rest, state}
    end
  end

  defp decode_long_shared_name(<<index::16-big, rest::binary>>, state) do
    get_shared_name(index, rest, state)
  end

  defp decode_long_shared_name(_rest, _state) do
    {:error, :incomplete_shared_name_reference}
  end

  # Add shared name to state
  defp add_shared_name(name, state) do
    if length(state.name_list) < C.max_shared_names() do
      %{state | name_list: state.name_list ++ [name]}
    else
      state
    end
  end

  # Decode variable-length integer
  defp decode_vint(binary) do
    decode_vint_bytes(binary, 0, 0)
  end

  defp decode_vint_bytes(<<byte::8, rest::binary>>, acc, shift) do
    value = acc ||| (byte &&& 0x7F) <<< shift

    if (byte &&& 0x80) == 0 do
      {:ok, value, rest}
    else
      decode_vint_bytes(rest, value, shift + 7)
    end
  end

  defp decode_vint_bytes(<<>>, _acc, _shift) do
    {:error, :incomplete_vint}
  end
end
