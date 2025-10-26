# Demo script for the Smile library
# Run with: mix run examples/demo.exs

IO.puts("=" |> String.duplicate(60))
IO.puts("Smile Binary Format Demo")
IO.puts("=" |> String.duplicate(60))
IO.puts("")

# Example 1: Simple values
IO.puts("1. Encoding Simple Values")
IO.puts("-" |> String.duplicate(40))

simple_values = [
  nil,
  true,
  false,
  42,
  3.14159,
  "hello world"
]

for value <- simple_values do
  {:ok, encoded} = Smile.encode(value)
  {:ok, decoded} = Smile.decode(encoded)

  IO.puts("  Original: #{inspect(value)}")
  IO.puts("  Encoded size: #{byte_size(encoded)} bytes")
  IO.puts("  Decoded: #{inspect(decoded)}")
  IO.puts("  Match: #{inspect(value) == inspect(decoded)}")
  IO.puts("")
end

# Example 2: Arrays
IO.puts("\n2. Encoding Arrays")
IO.puts("-" |> String.duplicate(40))

array = [1, 2, 3, 4, 5]
{:ok, encoded} = Smile.encode(array)
{:ok, decoded} = Smile.decode(encoded)

IO.puts("  Original: #{inspect(array)}")
IO.puts("  Encoded size: #{byte_size(encoded)} bytes")
IO.puts("  Decoded: #{inspect(decoded)}")
IO.puts("  Match: #{array == decoded}")
IO.puts("")

# Example 3: Objects
IO.puts("\n3. Encoding Objects")
IO.puts("-" |> String.duplicate(40))

user = %{
  "name" => "Alice",
  "age" => 30,
  "email" => "alice@example.com",
  "active" => true
}

{:ok, encoded} = Smile.encode(user)
{:ok, decoded} = Smile.decode(encoded)

IO.puts("  Original: #{inspect(user)}")
IO.puts("  Encoded size: #{byte_size(encoded)} bytes")
IO.puts("  Decoded: #{inspect(decoded)}")
IO.puts("  Match: #{user == decoded}")
IO.puts("")

# Example 4: Nested structures
IO.puts("\n4. Encoding Nested Structures")
IO.puts("-" |> String.duplicate(40))

nested = %{
  "users" => [
    %{"name" => "Alice", "score" => 95},
    %{"name" => "Bob", "score" => 87}
  ],
  "metadata" => %{
    "version" => "1.0",
    "count" => 2
  }
}

{:ok, encoded} = Smile.encode(nested)
{:ok, decoded} = Smile.decode(encoded)

IO.puts("  Original: #{inspect(nested, pretty: true)}")
IO.puts("  Encoded size: #{byte_size(encoded)} bytes")
IO.puts("  Decoded: #{inspect(decoded, pretty: true)}")
IO.puts("  Match: #{nested == decoded}")
IO.puts("")

# Example 5: Comparing with JSON (if Jason is available)
IO.puts("\n5. Size Comparison with JSON")
IO.puts("-" |> String.duplicate(40))

test_data = %{
  "users" => [
    %{"name" => "Alice", "age" => 30},
    %{"name" => "Bob", "age" => 25},
    %{"name" => "Charlie", "age" => 35}
  ]
}

{:ok, smile_encoded} = Smile.encode(test_data)

case Code.ensure_loaded?(Jason) do
  true ->
    json_encoded = Jason.encode!(test_data)

    IO.puts("  Data: #{inspect(test_data)}")
    IO.puts("  JSON size: #{byte_size(json_encoded)} bytes")
    IO.puts("  Smile size: #{byte_size(smile_encoded)} bytes")
    IO.puts("  Reduction: #{Float.round((1 - byte_size(smile_encoded) / byte_size(json_encoded)) * 100, 1)}%")

  false ->
    IO.puts("  JSON encoder (Jason) not available for comparison")
    IO.puts("  Smile size: #{byte_size(smile_encoded)} bytes")
end

IO.puts("")

# Example 6: Shared names optimization
IO.puts("\n6. Shared Names Optimization")
IO.puts("-" |> String.duplicate(40))

repeated_keys = %{
  "name" => "Alice",
  "data" => %{
    "name" => "Bob",
    "nested" => %{
      "name" => "Charlie"
    }
  }
}

{:ok, with_shared} = Smile.encode(repeated_keys, shared_names: true)
{:ok, without_shared} = Smile.encode(repeated_keys, shared_names: false)

IO.puts("  With shared names: #{byte_size(with_shared)} bytes")
IO.puts("  Without shared names: #{byte_size(without_shared)} bytes")
IO.puts("  Savings: #{byte_size(without_shared) - byte_size(with_shared)} bytes")
IO.puts("")

IO.puts("=" |> String.duplicate(60))
IO.puts("Demo Complete!")
IO.puts("=" |> String.duplicate(60))
