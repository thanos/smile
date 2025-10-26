defmodule Smile.Encoder do
  @moduledoc """
  Provides functionality to encode Elixir terms into Smile binary format.

  The encoder handles all JSON-compatible data types and provides optimization
  features such as back-references for field names and string values to reduce
  output size.

  ## Supported Types

  The encoder supports the following Elixir types:

    * `nil` - Encoded as Smile null token
    * `true`, `false` - Encoded as Smile boolean tokens
    * Integers - Encoded with variable-length encoding (small int, 32-bit, 64-bit)
    * Floats - Encoded as 64-bit IEEE double precision
    * Strings (binaries) - Encoded with length optimization (tiny, small, long)
    * Lists - Encoded as Smile arrays
    * Maps - Encoded as Smile objects
    * Atoms - Converted to strings and encoded

  ## Encoding Options

  The encoder accepts the following options:

    * `:shared_names` (boolean, default: `true`) - Enable back-references for
      field names. When enabled, repeated object keys are stored once and
      referenced in subsequent occurrences, reducing output size.

    * `:shared_values` (boolean, default: `true`) - Enable back-references for
      short string values (64 bytes or less). Similar to shared names, but for
      string values.

    * `:raw_binary` (boolean, default: `false`) - Allow raw binary data in the
      output. When enabled, binary data can be included without escaping.

  ## Examples

      # Basic encoding
      iex> Smile.Encoder.encode("hello")
      {:ok, <<58, 41, 10, 3, ...>>}

      # Encoding with options
      iex> Smile.Encoder.encode(%{"key" => "value"}, shared_names: false)
      {:ok, <<58, 41, 10, 0, ...>>}

  ## Implementation Details

  The encoder implements the following optimizations:

    * Small integers (-16 to +15) are encoded in a single byte
    * Variable-length integer encoding (VInt) for efficient number representation
    * ZigZag encoding for signed integers
    * String encoding optimization based on length and character set (ASCII vs Unicode)
    * Back-references for repeated field names and values
  """

  import Bitwise
  alias Smile.Constants, as: C

  @doc """
  Encodes an Elixir term into Smile binary format.

  ## Options
    * `:shared_names` - Enable back references for field names (default: true)
    * `:shared_values` - Enable back references for string values (default: true)
    * `:raw_binary` - Allow raw binary values (default: false)

  ## Examples

      iex> Smile.Encoder.encode(%{"hello" => "world"})
      {:ok, <<0x3A, 0x29, 0x0A, 0x03, 0xFA, ...>>}
  """
  def encode(term, opts \\ []) do
    shared_names = Keyword.get(opts, :shared_names, true)
    shared_values = Keyword.get(opts, :shared_values, true)
    raw_binary = Keyword.get(opts, :raw_binary, false)

    state = %{
      shared_names: shared_names,
      shared_values: shared_values,
      raw_binary: raw_binary,
      name_refs: %{},
      name_list: [],
      value_refs: %{},
      value_list: []
    }

    header = encode_header(shared_names, shared_values, raw_binary)

    case encode_value(term, state) do
      {:ok, data, _state} -> {:ok, header <> data}
      {:error, reason} -> {:error, reason}
    end
  end

  # Encode the Smile header
  defp encode_header(shared_names, shared_values, raw_binary) do
    flags = 0
    flags = if shared_names, do: flags ||| C.header_bit_has_shared_names(), else: flags
    flags = if shared_values, do: flags ||| C.header_bit_has_shared_string_values(), else: flags
    flags = if raw_binary, do: flags ||| C.header_bit_has_raw_binary(), else: flags

    <<
      C.header_byte_1()::8,
      C.header_byte_2()::8,
      C.header_byte_3()::8,
      flags::8
    >>
  end

  # Encode different value types
  defp encode_value(nil, state) do
    {:ok, <<C.token_literal_null()::8>>, state}
  end

  defp encode_value(true, state) do
    {:ok, <<C.token_literal_true()::8>>, state}
  end

  defp encode_value(false, state) do
    {:ok, <<C.token_literal_false()::8>>, state}
  end

  defp encode_value(value, state) when is_integer(value) do
    encode_integer(value, state)
  end

  defp encode_value(value, state) when is_float(value) do
    encode_float(value, state)
  end

  defp encode_value(value, state) when is_binary(value) do
    encode_string(value, state)
  end

  defp encode_value(value, state) when is_list(value) do
    encode_array(value, state)
  end

  defp encode_value(value, state) when is_map(value) do
    encode_object(value, state)
  end

  defp encode_value(value, state) when is_atom(value) do
    # Convert atoms to strings
    encode_string(Atom.to_string(value), state)
  end

  defp encode_value(_value, _state) do
    {:error, :unsupported_type}
  end

  # Encode integers
  defp encode_integer(value, state) when value >= -16 and value <= 15 do
    # Small int: 4-bit value encoded in single byte
    token = C.token_prefix_small_int() + (value &&& 0x1F)
    {:ok, <<token::8>>, state}
  end

  defp encode_integer(value, state) when value >= -2_147_483_648 and value <= 2_147_483_647 do
    # 32-bit integer
    zigzag = encode_zigzag(value)
    {:ok, <<C.token_byte_int_32()::8, zigzag::32-big>>, state}
  end

  defp encode_integer(value, state) do
    # 64-bit integer
    zigzag = encode_zigzag(value)
    {:ok, <<C.token_byte_int_64()::8, zigzag::64-big>>, state}
  end

  # ZigZag encoding for signed integers
  defp encode_zigzag(value) when value >= 0, do: value * 2
  defp encode_zigzag(value), do: -value * 2 - 1

  # Encode floating point numbers
  defp encode_float(value, state) do
    # Use 64-bit double precision
    {:ok, <<C.token_byte_float_64()::8, value::float-64-big>>, state}
  end

  # Encode strings
  defp encode_string("", state) do
    {:ok, <<C.token_literal_empty_string()::8>>, state}
  end

  defp encode_string(value, state) do
    bytes = :erlang.iolist_to_binary(value)
    byte_len = byte_size(bytes)

    cond do
      # Check for shared string reference (if enabled and string is short enough)
      state.shared_values and byte_len <= C.max_short_value_string_bytes() ->
        case Map.get(state.value_refs, value) do
          nil ->
            # Not yet seen, encode and add to references
            {token, new_state} = add_value_reference(value, state)
            {:ok, token <> encode_string_bytes(bytes, byte_len), new_state}

          index ->
            # Use back reference
            {:ok, encode_shared_string_reference(index), state}
        end

      # Tiny ASCII (1-32 bytes, ASCII only)
      byte_len <= 32 and ascii?(bytes) ->
        token = C.token_prefix_tiny_ascii() + (byte_len - 1)
        {:ok, <<token::8>> <> bytes, state}

      # Small ASCII (33-64 bytes, ASCII only)
      byte_len <= 64 and ascii?(bytes) ->
        token = C.token_prefix_small_ascii() + (byte_len - 33)
        {:ok, <<token::8>> <> bytes, state}

      # Long ASCII
      ascii?(bytes) ->
        {:ok,
         <<C.token_misc_long_text_ascii()::8>> <>
           encode_vint(byte_len) <> bytes <> <<C.byte_marker_end_of_string()::8>>, state}

      # Tiny Unicode (2-33 bytes)
      byte_len >= 2 and byte_len <= 33 ->
        token = C.token_prefix_tiny_unicode() + (byte_len - 2)
        {:ok, <<token::8>> <> bytes, state}

      # Short Unicode (34-64 bytes)
      byte_len <= 64 ->
        token = C.token_prefix_short_unicode() + (byte_len - 34)
        {:ok, <<token::8>> <> bytes, state}

      # Long Unicode
      true ->
        {:ok,
         <<C.token_misc_long_text_unicode()::8>> <>
           encode_vint(byte_len) <> bytes <> <<C.byte_marker_end_of_string()::8>>, state}
    end
  end

  defp encode_string_bytes(bytes, byte_len) do
    cond do
      byte_len <= 32 and ascii?(bytes) ->
        token = C.token_prefix_tiny_ascii() + (byte_len - 1)
        <<token::8>> <> bytes

      byte_len <= 64 and ascii?(bytes) ->
        token = C.token_prefix_small_ascii() + (byte_len - 33)
        <<token::8>> <> bytes

      ascii?(bytes) ->
        <<C.token_misc_long_text_ascii()::8>> <>
          encode_vint(byte_len) <> bytes <> <<C.byte_marker_end_of_string()::8>>

      byte_len >= 2 and byte_len <= 33 ->
        token = C.token_prefix_tiny_unicode() + (byte_len - 2)
        <<token::8>> <> bytes

      byte_len <= 64 ->
        token = C.token_prefix_short_unicode() + (byte_len - 34)
        <<token::8>> <> bytes

      true ->
        <<C.token_misc_long_text_unicode()::8>> <>
          encode_vint(byte_len) <> bytes <> <<C.byte_marker_end_of_string()::8>>
    end
  end

  # Encode arrays
  defp encode_array(list, state) do
    {items_data, final_state} =
      Enum.reduce_while(list, {<<>>, state}, fn item, {acc, st} ->
        case encode_value(item, st) do
          {:ok, data, new_state} -> {:cont, {acc <> data, new_state}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case items_data do
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:ok,
         <<C.token_literal_start_array()::8>> <> items_data <> <<C.token_literal_end_array()::8>>,
         final_state}
    end
  end

  # Encode objects (maps)
  defp encode_object(map, state) do
    {items_data, final_state} =
      Enum.reduce_while(map, {<<>>, state}, fn {key, value}, {acc, st} ->
        key_str = to_string(key)

        {:ok, key_data, st2} = encode_field_name(key_str, st)

        case encode_value(value, st2) do
          {:ok, value_data, st3} -> {:cont, {acc <> key_data <> value_data, st3}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case items_data do
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:ok,
         <<C.token_literal_start_object()::8>> <>
           items_data <> <<C.token_literal_end_object()::8>>, final_state}
    end
  end

  # Encode field names (keys in objects)
  defp encode_field_name("", state) do
    {:ok, <<C.token_key_empty_string()::8>>, state}
  end

  defp encode_field_name(name, state) do
    # Check for shared name reference
    if state.shared_names do
      case Map.get(state.name_refs, name) do
        nil ->
          # Not yet seen, encode and add to references
          new_state = add_name_reference(name, state)
          {:ok, encode_field_name_bytes(name), new_state}

        index when index < 64 ->
          # Short reference
          token = C.token_prefix_key_shared_short() + index
          {:ok, <<token::8>>, state}

        index ->
          # Long reference (2 bytes)
          {:ok, <<C.token_prefix_key_shared_long()::8, index::16-big>>, state}
      end
    else
      {:ok, encode_field_name_bytes(name), state}
    end
  end

  defp encode_field_name_bytes(name) do
    bytes = :erlang.iolist_to_binary(name)
    byte_len = byte_size(bytes)

    cond do
      # ASCII short (1-56 bytes)
      byte_len <= 56 and ascii?(bytes) ->
        token = C.token_prefix_key_ascii() + (byte_len - 1)
        <<token::8>> <> bytes

      # Unicode short (1-56 bytes)
      byte_len <= 56 ->
        token = C.token_prefix_key_unicode() + (byte_len - 1)
        <<token::8>> <> bytes

      # Long string (with length prefix)
      true ->
        <<C.token_key_long_string()::8>> <>
          encode_vint(byte_len) <> bytes <> <<C.byte_marker_end_of_string()::8>>
    end
  end

  # Add name to reference table
  defp add_name_reference(name, state) do
    index = length(state.name_list)

    if index < C.max_shared_names() do
      %{
        state
        | name_refs: Map.put(state.name_refs, name, index),
          name_list: state.name_list ++ [name]
      }
    else
      state
    end
  end

  # Add value to reference table
  defp add_value_reference(value, state) do
    index = length(state.value_list)

    if index < C.max_shared_string_values() do
      new_state = %{
        state
        | value_refs: Map.put(state.value_refs, value, index),
          value_list: state.value_list ++ [value]
      }

      {<<>>, new_state}
    else
      {<<>>, state}
    end
  end

  # Encode shared string reference
  defp encode_shared_string_reference(index) when index < 31 do
    # Short reference: single byte
    token = C.token_prefix_shared_string_short() + (index + 1)
    <<token::8>>
  end

  defp encode_shared_string_reference(index) do
    # Long reference: 2 bytes
    <<C.token_prefix_shared_string_long()::8, index - 31::8>>
  end

  # Variable-length integer encoding
  defp encode_vint(value) when value < 0x80 do
    <<value::8>>
  end

  defp encode_vint(value) do
    encode_vint_bytes(value, <<>>)
  end

  defp encode_vint_bytes(0, acc), do: acc

  defp encode_vint_bytes(value, acc) when value < 0x80 do
    acc <> <<value::8>>
  end

  defp encode_vint_bytes(value, acc) do
    byte = (value &&& 0x7F) ||| 0x80
    encode_vint_bytes(value >>> 7, acc <> <<byte::8>>)
  end

  # Check if binary contains only ASCII characters
  defp ascii?(binary) do
    :binary.bin_to_list(binary)
    |> Enum.all?(&(&1 < 128))
  end
end
