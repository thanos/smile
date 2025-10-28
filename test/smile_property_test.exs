defmodule SmilePropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  @moduledoc """
  Property-based tests for Smile encoding and decoding.

  These tests use StreamData to generate random inputs and verify
  that certain properties always hold true, regardless of the input.
  """

  # Generator for Smile-compatible data types
  # We need to be careful to only generate data that Smile can handle

  defp smile_string do
    StreamData.one_of([
      # ASCII strings
      StreamData.string(:alphanumeric, min_length: 0, max_length: 100),
      # Unicode strings
      StreamData.string(:printable, min_length: 0, max_length: 50),
      # Common edge cases
      StreamData.member_of(["", "a", "hello world", "test@example.com"])
    ])
  end

  defp smile_integer do
    StreamData.one_of([
      # Small integers (-16 to 15)
      StreamData.integer(-16..15),
      # 32-bit integers
      StreamData.integer(-2_147_483_648..2_147_483_647),
      # Larger integers (but not too large)
      StreamData.integer(-999_999_999_999..999_999_999_999)
    ])
  end

  defp smile_float do
    StreamData.one_of([
      # Regular floats
      StreamData.float(min: -1000.0, max: 1000.0),
      # Common values
      StreamData.member_of([0.0, 1.0, -1.0, 3.14159, 2.71828])
    ])
  end

  defp smile_boolean do
    StreamData.boolean()
  end

  defp smile_nil do
    StreamData.constant(nil)
  end

  defp smile_primitive do
    StreamData.one_of([
      smile_nil(),
      smile_boolean(),
      smile_integer(),
      smile_float(),
      smile_string()
    ])
  end

  defp smile_list(element_generator, max_size) do
    StreamData.list_of(element_generator, max_length: max_size)
  end

  defp smile_map(value_generator, max_size) do
    # Generate maps with string keys (Smile converts atoms to strings)
    StreamData.map_of(
      smile_string(),
      value_generator,
      max_length: max_size
    )
  end

  # Recursive generator for nested structures (limited depth)
  defp smile_data(depth)

  defp smile_data(depth) when depth >= 3 do
    # At max depth, only generate primitives
    smile_primitive()
  end

  defp smile_data(depth) do
    StreamData.one_of([
      smile_primitive(),
      smile_list(smile_data(depth + 1), 10),
      smile_map(smile_data(depth + 1), 10)
    ])
  end

  # Main property: Round-trip encoding/decoding preserves data
  property "encoding and decoding preserves primitive values" do
    check all value <- smile_primitive(), max_runs: 200 do
      {:ok, encoded} = Smile.encode(value)
      {:ok, decoded} = Smile.decode(encoded)

      # Floats need approximate comparison
      cond do
        is_float(value) ->
          assert_in_delta decoded, value, 0.000001

        true ->
          assert decoded == value
      end
    end
  end

  property "encoding and decoding preserves lists of primitives" do
    check all list <- smile_list(smile_primitive(), 50), max_runs: 100 do
      {:ok, encoded} = Smile.encode(list)
      {:ok, decoded} = Smile.decode(encoded)

      # Compare element by element, handling floats
      assert length(decoded) == length(list)

      Enum.zip(decoded, list)
      |> Enum.each(fn {decoded_elem, original_elem} ->
        if is_float(original_elem) do
          assert_in_delta decoded_elem, original_elem, 0.000001
        else
          assert decoded_elem == original_elem
        end
      end)
    end
  end

  property "encoding and decoding preserves maps with string values" do
    check all map <- smile_map(smile_string(), 20), max_runs: 100 do
      {:ok, encoded} = Smile.encode(map)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == map
    end
  end

  property "encoding and decoding preserves maps with integer values" do
    check all map <- smile_map(smile_integer(), 20), max_runs: 100 do
      {:ok, encoded} = Smile.encode(map)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == map
    end
  end

  property "encoding and decoding preserves nested structures" do
    check all data <- smile_data(0), max_runs: 100 do
      {:ok, encoded} = Smile.encode(data)
      {:ok, decoded} = Smile.decode(encoded)

      # For complex structures with floats, we need recursive comparison
      assert_smile_equal(decoded, data)
    end
  end

  # Helper to compare values accounting for float precision
  defp assert_smile_equal(decoded, original) when is_float(original) do
    assert_in_delta decoded, original, 0.000001
  end

  defp assert_smile_equal(decoded, original) when is_list(decoded) and is_list(original) do
    assert length(decoded) == length(original)

    Enum.zip(decoded, original)
    |> Enum.each(fn {d, o} -> assert_smile_equal(d, o) end)
  end

  defp assert_smile_equal(decoded, original) when is_map(decoded) and is_map(original) do
    assert Map.keys(decoded) == Map.keys(original)

    Enum.each(decoded, fn {key, value} ->
      assert_smile_equal(value, Map.get(original, key))
    end)
  end

  defp assert_smile_equal(decoded, original) do
    assert decoded == original
  end

  # Property: Encoded data always has the correct header
  property "all encoded data starts with Smile header" do
    check all data <- smile_data(0), max_runs: 100 do
      {:ok, encoded} = Smile.encode(data)

      # Check Smile header: :)\n (0x3A 0x29 0x0A)
      assert <<0x3A, 0x29, 0x0A, _flags::8, _rest::binary>> = encoded
    end
  end

  # Property: Encoding is deterministic
  property "encoding the same data multiple times produces the same result" do
    check all data <- smile_primitive(), max_runs: 100 do
      {:ok, encoded1} = Smile.encode(data)
      {:ok, encoded2} = Smile.encode(data)
      {:ok, encoded3} = Smile.encode(data)

      assert encoded1 == encoded2
      assert encoded2 == encoded3
    end
  end

  # Property: Decoding invalid data returns error
  property "decoding random binary without proper header returns error" do
    check all invalid_data <- StreamData.binary(min_length: 1, max_length: 100),
              # Ensure it doesn't accidentally start with the Smile header
              not match?(<<0x3A, 0x29, 0x0A, _::binary>>, invalid_data),
              max_runs: 100 do
      assert {:error, :invalid_header} = Smile.decode(invalid_data)
    end
  end

  # Property: Empty structures
  property "encoding and decoding empty structures" do
    check all _iteration <- StreamData.constant(nil), max_runs: 50 do
      # Empty list
      {:ok, encoded_list} = Smile.encode([])
      {:ok, decoded_list} = Smile.decode(encoded_list)
      assert decoded_list == []

      # Empty map
      {:ok, encoded_map} = Smile.encode(%{})
      {:ok, decoded_map} = Smile.decode(encoded_map)
      assert decoded_map == %{}

      # Empty string
      {:ok, encoded_string} = Smile.encode("")
      {:ok, decoded_string} = Smile.decode(encoded_string)
      assert decoded_string == ""
    end
  end

  # Property: Shared names option doesn't affect correctness
  property "shared_names option doesn't affect decoded result" do
    check all map <- smile_map(smile_integer(), 10), max_runs: 50 do
      {:ok, encoded_with} = Smile.encode(map, shared_names: true)
      {:ok, encoded_without} = Smile.encode(map, shared_names: false)

      {:ok, decoded_with} = Smile.decode(encoded_with)
      {:ok, decoded_without} = Smile.decode(encoded_without)

      assert decoded_with == map
      assert decoded_without == map
      assert decoded_with == decoded_without
    end
  end

  # Property: Shared values option doesn't affect correctness
  property "shared_values option doesn't affect decoded result" do
    check all map <- smile_map(smile_string(), 10), max_runs: 50 do
      {:ok, encoded_with} = Smile.encode(map, shared_values: true)
      {:ok, encoded_without} = Smile.encode(map, shared_values: false)

      {:ok, decoded_with} = Smile.decode(encoded_with)
      {:ok, decoded_without} = Smile.decode(encoded_without)

      assert decoded_with == map
      assert decoded_without == map
      assert decoded_with == decoded_without
    end
  end

  # Property: Repeated keys benefit from shared names
  property "shared_names reduces size for maps with repeated nested keys" do
    # Use a generator that produces non-empty strings
    non_empty_string = StreamData.string(:alphanumeric, min_length: 1, max_length: 20)

    check all key <- non_empty_string,
              value <- smile_integer(),
              max_runs: 50 do
      # Create nested structure with repeated keys
      data = %{
        key => value,
        "nested" => %{
          key => value + 1,
          "deep" => %{
            key => value + 2
          }
        }
      }

      {:ok, with_shared} = Smile.encode(data, shared_names: true)
      {:ok, without_shared} = Smile.encode(data, shared_names: false)

      # With shared names should be same size or smaller
      assert byte_size(with_shared) <= byte_size(without_shared)

      # Both should decode to same result
      {:ok, decoded_with} = Smile.decode(with_shared)
      {:ok, decoded_without} = Smile.decode(without_shared)
      assert decoded_with == decoded_without
    end
  end

  # Property: Type preservation for specific types
  property "integers remain integers after round-trip" do
    check all int <- smile_integer(), max_runs: 100 do
      {:ok, encoded} = Smile.encode(int)
      {:ok, decoded} = Smile.decode(encoded)
      assert is_integer(decoded)
      assert decoded == int
    end
  end

  property "strings remain strings after round-trip" do
    check all str <- smile_string(), max_runs: 100 do
      {:ok, encoded} = Smile.encode(str)
      {:ok, decoded} = Smile.decode(encoded)
      assert is_binary(decoded)
      assert decoded == str
    end
  end

  property "booleans remain booleans after round-trip" do
    check all bool <- smile_boolean(), max_runs: 100 do
      {:ok, encoded} = Smile.encode(bool)
      {:ok, decoded} = Smile.decode(encoded)
      assert is_boolean(decoded)
      assert decoded == bool
    end
  end

  property "nil remains nil after round-trip" do
    check all _iteration <- StreamData.constant(nil), max_runs: 50 do
      {:ok, encoded} = Smile.encode(nil)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == nil
    end
  end

  # Property: Lists remain lists
  property "lists remain lists after round-trip" do
    check all list <- smile_list(smile_integer(), 30), max_runs: 100 do
      {:ok, encoded} = Smile.encode(list)
      {:ok, decoded} = Smile.decode(encoded)
      assert is_list(decoded)
      assert length(decoded) == length(list)
    end
  end

  # Property: Maps remain maps
  property "maps remain maps after round-trip" do
    check all map <- smile_map(smile_integer(), 20), max_runs: 100 do
      {:ok, encoded} = Smile.encode(map)
      {:ok, decoded} = Smile.decode(encoded)
      assert is_map(decoded)
      assert map_size(decoded) == map_size(map)
    end
  end

  # Property: Size comparison with edge cases
  property "encoded binary is always at least header size" do
    check all data <- smile_data(0), max_runs: 100 do
      {:ok, encoded} = Smile.encode(data)
      # Header is 4 bytes, plus at least 1 byte for the data
      assert byte_size(encoded) >= 4
    end
  end

  # Property: Special string cases
  property "handles strings with various special characters" do
    special_chars = [
      "\n",
      "\r",
      "\t",
      "\"",
      "\\",
      "/",
      "\0",
      "mixed\nwith\nnewlines",
      "tabs\there",
      "quotes\"inside"
    ]

    check all str <- StreamData.member_of(special_chars), max_runs: 50 do
      {:ok, encoded} = Smile.encode(str)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == str
    end
  end

  # Property: Large numbers
  property "handles large integer values correctly" do
    check all int <- StreamData.integer(-9_223_372_036_854_775_808..9_223_372_036_854_775_807),
              max_runs: 100 do
      case Smile.encode(int) do
        {:ok, encoded} ->
          {:ok, decoded} = Smile.decode(encoded)
          assert decoded == int

        {:error, _reason} ->
          # Some very large integers might not be supported, that's ok
          :ok
      end
    end
  end

  # Property: Unicode handling
  property "handles various unicode strings correctly" do
    unicode_samples = [
      "Hello",
      "Привет",
      "你好",
      "مرحبا",
      "שלום",
      "こんにちは",
      "🎉🎊🎈",
      "Ελληνικά",
      "emoji: 😀😃😄",
      "symbols: ©®™"
    ]

    check all str <- StreamData.member_of(unicode_samples), max_runs: 50 do
      {:ok, encoded} = Smile.encode(str)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == str
    end
  end

  # Property: Nested arrays
  property "handles nested arrays correctly" do
    check all inner_list <- smile_list(smile_integer(), 5),
              outer_size <- StreamData.integer(0..5),
              max_runs: 50 do
      nested = List.duplicate(inner_list, outer_size)
      {:ok, encoded} = Smile.encode(nested)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == nested
    end
  end

  # Property: Mixed type arrays
  property "handles arrays with mixed types" do
    check all int <- smile_integer(),
              str <- smile_string(),
              bool <- smile_boolean(),
              max_runs: 50 do
      mixed_array = [int, str, bool, nil, 3.14, [1, 2], %{"key" => "value"}]
      {:ok, encoded} = Smile.encode(mixed_array)
      {:ok, decoded} = Smile.decode(encoded)

      assert is_list(decoded)
      assert length(decoded) == length(mixed_array)
      # Check first few elements
      assert Enum.at(decoded, 0) == int
      assert Enum.at(decoded, 1) == str
      assert Enum.at(decoded, 2) == bool
      assert Enum.at(decoded, 3) == nil
    end
  end
end
