# Quick benchmark comparison between SmileEx and Jason
# Run with: mix run benchmarks/quick.exs

IO.puts("\n")
IO.puts("Quick SmileEx vs Jason Benchmark")
IO.puts("=" |> String.duplicate(60))
IO.puts("")

# Sample data
data = %{
  "users" => [
    %{"id" => 1, "name" => "Alice", "email" => "alice@example.com", "age" => 30},
    %{"id" => 2, "name" => "Bob", "email" => "bob@example.com", "age" => 25},
    %{"id" => 3, "name" => "Charlie", "email" => "charlie@example.com", "age" => 35}
  ],
  "metadata" => %{
    "version" => "1.0",
    "timestamp" => "2025-10-26T12:00:00Z"
  }
}

# Encode data
smile_binary = Smile.encode!(data)
json_string = Jason.encode!(data)

# Display size comparison
IO.puts("Size Comparison:")
IO.puts("  JSON:  #{byte_size(json_string)} bytes")
IO.puts("  Smile: #{byte_size(smile_binary)} bytes")
IO.puts("  Reduction: #{Float.round((1 - byte_size(smile_binary) / byte_size(json_string)) * 100, 1)}%")
IO.puts("")

# Quick performance test
IO.puts("Running benchmarks...")
IO.puts("")

Benchee.run(
  %{
    "Jason encode" => fn -> Jason.encode!(data) end,
    "SmileEx encode" => fn -> Smile.encode!(data) end,
    "Jason decode" => fn -> Jason.decode!(json_string) end,
    "SmileEx decode" => fn -> Smile.decode!(smile_binary) end,
    "Jason round-trip" => fn ->
      json = Jason.encode!(data)
      Jason.decode!(json)
    end,
    "SmileEx round-trip" => fn ->
      binary = Smile.encode!(data)
      Smile.decode!(binary)
    end
  },
  time: 3,
  memory_time: 1,
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: false}
  ]
)

IO.puts("")
IO.puts("=" |> String.duplicate(60))
IO.puts("Benchmark complete!")
IO.puts("")
