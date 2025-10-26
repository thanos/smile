defmodule SmileTest do
  use ExUnit.Case
  import Bitwise
  doctest Smile

  describe "encode/1" do
    test "encodes nil" do
      assert {:ok, binary} = Smile.encode(nil)
      # Header (4 bytes) + null token (1 byte)
      assert byte_size(binary) >= 5
      assert <<0x3A, 0x29, 0x0A, _flags::8, rest::binary>> = binary
      assert rest == <<0x21>>
    end

    test "encodes true" do
      assert {:ok, binary} = Smile.encode(true)
      assert <<0x3A, 0x29, 0x0A, _flags::8, rest::binary>> = binary
      assert rest == <<0x23>>
    end

    test "encodes false" do
      assert {:ok, binary} = Smile.encode(false)
      assert <<0x3A, 0x29, 0x0A, _flags::8, rest::binary>> = binary
      assert rest == <<0x22>>
    end

    test "encodes small positive integers" do
      # Small int range: -16 to +15
      assert {:ok, binary} = Smile.encode(5)
      assert <<0x3A, 0x29, 0x0A, _flags::8, token::8>> = binary
      assert (token &&& 0xE0) == 0xC0  # Small int prefix
    end

    test "encodes small negative integers" do
      assert {:ok, binary} = Smile.encode(-5)
      assert <<0x3A, 0x29, 0x0A, _flags::8, token::8>> = binary
      assert (token &&& 0xE0) == 0xC0  # Small int prefix
    end

    test "encodes 32-bit integers" do
      assert {:ok, binary} = Smile.encode(1000)
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0x24::8, _rest::binary>> = binary
    end

    test "encodes large integers" do
      assert {:ok, binary} = Smile.encode(999_999_999_999)
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0x25::8, _rest::binary>> = binary
    end

    test "encodes floats" do
      assert {:ok, binary} = Smile.encode(3.14159)
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0x29::8, _rest::binary>> = binary
    end

    test "encodes empty string" do
      assert {:ok, binary} = Smile.encode("")
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0x20::8>> = binary
    end

    test "encodes short ASCII strings" do
      assert {:ok, binary} = Smile.encode("hello")
      assert <<0x3A, 0x29, 0x0A, _flags::8, token::8, "hello">> = binary
      # Tiny ASCII prefix (0x40) + length - 1
      assert (token &&& 0xE0) == 0x40
    end

    test "encodes longer ASCII strings" do
      str = String.duplicate("a", 40)
      assert {:ok, binary} = Smile.encode(str)
      assert <<0x3A, 0x29, 0x0A, _flags::8, _token::8, rest::binary>> = binary
      assert String.starts_with?(rest, str)
    end

    test "encodes Unicode strings" do
      assert {:ok, binary} = Smile.encode("héllo")
      assert <<0x3A, 0x29, 0x0A, _flags::8, _token::8, _rest::binary>> = binary
    end

    test "encodes empty array" do
      assert {:ok, binary} = Smile.encode([])
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0xF8::8, 0xF9::8>> = binary
    end

    test "encodes array with values" do
      assert {:ok, binary} = Smile.encode([1, 2, 3])
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0xF8::8, _rest::binary>> = binary
      assert String.ends_with?(binary, <<0xF9>>)
    end

    test "encodes nested arrays" do
      assert {:ok, binary} = Smile.encode([[1, 2], [3, 4]])
      assert <<0x3A, 0x29, 0x0A, _flags::8, _rest::binary>> = binary
    end

    test "encodes empty object" do
      assert {:ok, binary} = Smile.encode(%{})
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0xFA::8, 0xFB::8>> = binary
    end

    test "encodes simple object" do
      assert {:ok, binary} = Smile.encode(%{"a" => 1})
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0xFA::8, _rest::binary>> = binary
      assert String.ends_with?(binary, <<0xFB>>)
    end

    test "encodes object with multiple keys" do
      assert {:ok, binary} = Smile.encode(%{"name" => "Alice", "age" => 30})
      assert <<0x3A, 0x29, 0x0A, _flags::8, 0xFA::8, _rest::binary>> = binary
    end

    test "encodes nested objects" do
      data = %{"user" => %{"name" => "Alice", "age" => 30}}
      assert {:ok, binary} = Smile.encode(data)
      assert <<0x3A, 0x29, 0x0A, _flags::8, _rest::binary>> = binary
    end

    test "encodes complex nested structure" do
      data = %{
        "users" => [
          %{"name" => "Alice", "active" => true},
          %{"name" => "Bob", "active" => false}
        ],
        "count" => 2
      }

      assert {:ok, binary} = Smile.encode(data)
      assert <<0x3A, 0x29, 0x0A, _flags::8, _rest::binary>> = binary
    end

    test "encodes with shared_names option disabled" do
      data = %{"a" => 1, "b" => 2}
      assert {:ok, binary} = Smile.encode(data, shared_names: false)
      assert <<0x3A, 0x29, 0x0A, flags::8, _rest::binary>> = binary
      # Shared names bit should not be set
      assert (flags &&& 0x01) == 0
    end

    test "encodes with shared_values option enabled" do
      data = %{"a" => "test", "b" => "test"}
      assert {:ok, binary} = Smile.encode(data, shared_values: true)
      assert <<0x3A, 0x29, 0x0A, flags::8, _rest::binary>> = binary
      # Shared values bit should be set
      assert (flags &&& 0x02) == 0x02
    end

    test "encode! returns binary on success" do
      binary = Smile.encode!(%{"test" => true})
      assert is_binary(binary)
      assert <<0x3A, 0x29, 0x0A, _rest::binary>> = binary
    end
  end

  describe "decode/1" do
    test "decodes nil" do
      {:ok, binary} = Smile.encode(nil)
      assert {:ok, nil} = Smile.decode(binary)
    end

    test "decodes true" do
      {:ok, binary} = Smile.encode(true)
      assert {:ok, true} = Smile.decode(binary)
    end

    test "decodes false" do
      {:ok, binary} = Smile.encode(false)
      assert {:ok, false} = Smile.decode(binary)
    end

    test "decodes small integers" do
      for i <- -16..15 do
        {:ok, binary} = Smile.encode(i)
        assert {:ok, ^i} = Smile.decode(binary)
      end
    end

    test "decodes 32-bit integers" do
      values = [0, 100, -100, 1000, -1000, 2_147_483_647, -2_147_483_648]

      for val <- values do
        {:ok, binary} = Smile.encode(val)
        assert {:ok, ^val} = Smile.decode(binary)
      end
    end

    test "decodes 64-bit integers" do
      values = [999_999_999_999, -999_999_999_999]

      for val <- values do
        {:ok, binary} = Smile.encode(val)
        assert {:ok, ^val} = Smile.decode(binary)
      end
    end

    test "decodes floats" do
      values = [0.0, 3.14159, -2.71828, 1.23456789]

      for val <- values do
        {:ok, binary} = Smile.encode(val)
        assert {:ok, decoded} = Smile.decode(binary)
        assert_in_delta decoded, val, 0.000001
      end
    end

    test "decodes empty string" do
      {:ok, binary} = Smile.encode("")
      assert {:ok, ""} = Smile.decode(binary)
    end

    test "decodes ASCII strings" do
      strings = ["hello", "world", "test", String.duplicate("a", 50)]

      for str <- strings do
        {:ok, binary} = Smile.encode(str)
        assert {:ok, ^str} = Smile.decode(binary)
      end
    end

    test "decodes Unicode strings" do
      strings = ["héllo", "世界", "🎉", "Ελληνικά"]

      for str <- strings do
        {:ok, binary} = Smile.encode(str)
        assert {:ok, ^str} = Smile.decode(binary)
      end
    end

    test "decodes empty array" do
      {:ok, binary} = Smile.encode([])
      assert {:ok, []} = Smile.decode(binary)
    end

    test "decodes arrays with values" do
      arrays = [
        [1, 2, 3],
        ["a", "b", "c"],
        [true, false, nil],
        [1, "two", 3.0, true]
      ]

      for arr <- arrays do
        {:ok, binary} = Smile.encode(arr)
        assert {:ok, ^arr} = Smile.decode(binary)
      end
    end

    test "decodes nested arrays" do
      data = [[1, 2], [3, 4], [5, [6, 7]]]
      {:ok, binary} = Smile.encode(data)
      assert {:ok, ^data} = Smile.decode(binary)
    end

    test "decodes empty object" do
      {:ok, binary} = Smile.encode(%{})
      assert {:ok, %{}} = Smile.decode(binary)
    end

    test "decodes simple objects" do
      data = %{"name" => "Alice", "age" => 30}
      {:ok, binary} = Smile.encode(data)
      assert {:ok, ^data} = Smile.decode(binary)
    end

    test "decodes nested objects" do
      data = %{
        "user" => %{
          "name" => "Alice",
          "profile" => %{
            "age" => 30,
            "active" => true
          }
        }
      }

      {:ok, binary} = Smile.encode(data)
      assert {:ok, ^data} = Smile.decode(binary)
    end

    test "decodes complex structures" do
      data = %{
        "users" => [
          %{"name" => "Alice", "age" => 30, "active" => true},
          %{"name" => "Bob", "age" => 25, "active" => false}
        ],
        "count" => 2,
        "metadata" => %{
          "version" => "1.0",
          "timestamp" => 1234567890
        }
      }

      {:ok, binary} = Smile.encode(data)
      assert {:ok, ^data} = Smile.decode(binary)
    end

    test "returns error for invalid header" do
      assert {:error, :invalid_header} = Smile.decode(<<1, 2, 3, 4>>)
    end

    test "decode! returns term on success" do
      {:ok, binary} = Smile.encode(%{"test" => true})
      result = Smile.decode!(binary)
      assert result == %{"test" => true}
    end

    test "decode! raises on error" do
      assert_raise RuntimeError, fn ->
        Smile.decode!(<<1, 2, 3>>)
      end
    end
  end

  describe "round-trip encoding and decoding" do
    test "preserves data through encode/decode cycle" do
      test_cases = [
        nil,
        true,
        false,
        0,
        42,
        -42,
        3.14159,
        "",
        "hello",
        "hello world with spaces",
        "Unicode: 你好世界 🎉",
        [],
        [1, 2, 3],
        [1, "two", 3.0, true, nil],
        %{},
        %{"a" => 1},
        %{"name" => "Alice", "age" => 30},
        %{"users" => [%{"name" => "Alice"}, %{"name" => "Bob"}]},
        %{
          "string" => "value",
          "number" => 42,
          "float" => 3.14,
          "bool" => true,
          "null" => nil,
          "array" => [1, 2, 3],
          "object" => %{"nested" => true}
        }
      ]

      for data <- test_cases do
        {:ok, encoded} = Smile.encode(data)
        {:ok, decoded} = Smile.decode(encoded)

        # For floats, use approximate comparison
        if is_float(data) do
          assert_in_delta decoded, data, 0.000001
        else
          assert decoded == data
        end
      end
    end

    test "handles repeated field names with shared names" do
      data = %{
        "name" => "Alice",
        "data" => %{
          "name" => "Bob",
          "info" => %{
            "name" => "Charlie"
          }
        }
      }

      {:ok, encoded} = Smile.encode(data, shared_names: true)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == data
    end

    test "handles repeated string values with shared values" do
      repeated_value = "repeated"

      data = %{
        "a" => repeated_value,
        "b" => repeated_value,
        "c" => repeated_value
      }

      {:ok, encoded} = Smile.encode(data, shared_values: true)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == data
    end
  end

  describe "edge cases" do
    test "handles very long strings" do
      long_string = String.duplicate("x", 1000)
      {:ok, encoded} = Smile.encode(long_string)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == long_string
    end

    test "handles deeply nested structures" do
      deeply_nested =
        Enum.reduce(1..10, %{"value" => 42}, fn _i, acc ->
          %{"nested" => acc}
        end)

      {:ok, encoded} = Smile.encode(deeply_nested)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == deeply_nested
    end

    test "handles large arrays" do
      large_array = Enum.to_list(1..100)
      {:ok, encoded} = Smile.encode(large_array)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == large_array
    end

    test "handles objects with many keys" do
      many_keys =
        Enum.reduce(1..50, %{}, fn i, acc ->
          Map.put(acc, "key#{i}", i)
        end)

      {:ok, encoded} = Smile.encode(many_keys)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == many_keys
    end

    test "handles mixed types in arrays" do
      mixed = [
        1,
        "string",
        3.14,
        true,
        false,
        nil,
        [1, 2],
        %{"nested" => "object"}
      ]

      {:ok, encoded} = Smile.encode(mixed)
      {:ok, decoded} = Smile.decode(encoded)
      assert decoded == mixed
    end
  end
end
