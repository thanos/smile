# Benchmark comparison between SmileEx and Jason
# Run with: mix run benchmarks/comparison.exs

# Sample data sets for benchmarking
defmodule BenchmarkData do
  @moduledoc """
  Provides various test data sets for benchmarking SmileEx vs Jason
  """

  def small_map do
    %{
      "name" => "Alice",
      "age" => 30,
      "active" => true
    }
  end

  def medium_map do
    %{
      "id" => 12345,
      "username" => "alice_smith",
      "email" => "alice@example.com",
      "profile" => %{
        "first_name" => "Alice",
        "last_name" => "Smith",
        "age" => 30,
        "location" => "San Francisco",
        "verified" => true
      },
      "settings" => %{
        "notifications" => true,
        "theme" => "dark",
        "language" => "en"
      },
      "tags" => ["developer", "elixir", "functional"]
    }
  end

  def large_map do
    %{
      "users" => Enum.map(1..100, fn i ->
        %{
          "id" => i,
          "username" => "user_#{i}",
          "email" => "user#{i}@example.com",
          "age" => 20 + rem(i, 50),
          "active" => rem(i, 2) == 0,
          "score" => 1000 + i * 10,
          "tags" => ["tag#{rem(i, 5)}", "category#{rem(i, 3)}"]
        }
      end),
      "metadata" => %{
        "version" => "1.0",
        "timestamp" => "2025-10-26T12:00:00Z",
        "total" => 100
      }
    }
  end

  def array_of_numbers do
    Enum.to_list(1..1000)
  end

  def array_of_strings do
    Enum.map(1..100, fn i -> "string_value_#{i}" end)
  end

  def nested_structure do
    %{
      "level1" => %{
        "level2" => %{
          "level3" => %{
            "level4" => %{
              "level5" => %{
                "data" => [1, 2, 3, 4, 5],
                "info" => "deeply nested"
              }
            }
          }
        }
      }
    }
  end
end

IO.puts("=" |> String.duplicate(80))
IO.puts("SmileEx vs Jason Benchmark Comparison")
IO.puts("=" |> String.duplicate(80))
IO.puts("")

# Pre-encode data for decoding benchmarks
small_json = Jason.encode!(BenchmarkData.small_map())
small_smile = Smile.encode!(BenchmarkData.small_map())

medium_json = Jason.encode!(BenchmarkData.medium_map())
medium_smile = Smile.encode!(BenchmarkData.medium_map())

large_json = Jason.encode!(BenchmarkData.large_map())
large_smile = Smile.encode!(BenchmarkData.large_map())

# Display size comparison
IO.puts("Size Comparison:")
IO.puts("-" |> String.duplicate(80))
IO.puts("Small Map:")
IO.puts("  JSON: #{byte_size(small_json)} bytes | Smile: #{byte_size(small_smile)} bytes")
IO.puts("  Reduction: #{Float.round((1 - byte_size(small_smile) / byte_size(small_json)) * 100, 1)}%")
IO.puts("")
IO.puts("Medium Map:")
IO.puts("  JSON: #{byte_size(medium_json)} bytes | Smile: #{byte_size(medium_smile)} bytes")
IO.puts("  Reduction: #{Float.round((1 - byte_size(medium_smile) / byte_size(medium_json)) * 100, 1)}%")
IO.puts("")
IO.puts("Large Map (100 users):")
IO.puts("  JSON: #{byte_size(large_json)} bytes | Smile: #{byte_size(large_smile)} bytes")
IO.puts("  Reduction: #{Float.round((1 - byte_size(large_smile) / byte_size(large_json)) * 100, 1)}%")
IO.puts("")
IO.puts("=" |> String.duplicate(80))
IO.puts("")

# Encoding benchmarks
IO.puts("ENCODING BENCHMARKS")
IO.puts("=" |> String.duplicate(80))

Benchee.run(
  %{
    "SmileEx (small)" => fn -> Smile.encode!(BenchmarkData.small_map()) end,
    "Jason (small)" => fn -> Jason.encode!(BenchmarkData.small_map()) end,
    "SmileEx (medium)" => fn -> Smile.encode!(BenchmarkData.medium_map()) end,
    "Jason (medium)" => fn -> Jason.encode!(BenchmarkData.medium_map()) end,
    "SmileEx (large)" => fn -> Smile.encode!(BenchmarkData.large_map()) end,
    "Jason (large)" => fn -> Jason.encode!(BenchmarkData.large_map()) end,
    "SmileEx (numbers)" => fn -> Smile.encode!(BenchmarkData.array_of_numbers()) end,
    "Jason (numbers)" => fn -> Jason.encode!(BenchmarkData.array_of_numbers()) end,
    "SmileEx (strings)" => fn -> Smile.encode!(BenchmarkData.array_of_strings()) end,
    "Jason (strings)" => fn -> Jason.encode!(BenchmarkData.array_of_strings()) end,
    "SmileEx (nested)" => fn -> Smile.encode!(BenchmarkData.nested_structure()) end,
    "Jason (nested)" => fn -> Jason.encode!(BenchmarkData.nested_structure()) end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
  ]
)

IO.puts("")
IO.puts("=" |> String.duplicate(80))
IO.puts("DECODING BENCHMARKS")
IO.puts("=" |> String.duplicate(80))

# Decoding benchmarks
Benchee.run(
  %{
    "SmileEx (small)" => fn -> Smile.decode!(small_smile) end,
    "Jason (small)" => fn -> Jason.decode!(small_json) end,
    "SmileEx (medium)" => fn -> Smile.decode!(medium_smile) end,
    "Jason (medium)" => fn -> Jason.decode!(medium_json) end,
    "SmileEx (large)" => fn -> Smile.decode!(large_smile) end,
    "Jason (large)" => fn -> Jason.decode!(large_json) end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
  ]
)

IO.puts("")
IO.puts("=" |> String.duplicate(80))
IO.puts("ROUND-TRIP BENCHMARKS (Encode + Decode)")
IO.puts("=" |> String.duplicate(80))

# Round-trip benchmarks
Benchee.run(
  %{
    "SmileEx (small)" => fn ->
      data = BenchmarkData.small_map()
      binary = Smile.encode!(data)
      Smile.decode!(binary)
    end,
    "Jason (small)" => fn ->
      data = BenchmarkData.small_map()
      json = Jason.encode!(data)
      Jason.decode!(json)
    end,
    "SmileEx (medium)" => fn ->
      data = BenchmarkData.medium_map()
      binary = Smile.encode!(data)
      Smile.decode!(binary)
    end,
    "Jason (medium)" => fn ->
      data = BenchmarkData.medium_map()
      json = Jason.encode!(data)
      Jason.decode!(json)
    end,
    "SmileEx (large)" => fn ->
      data = BenchmarkData.large_map()
      binary = Smile.encode!(data)
      Smile.decode!(binary)
    end,
    "Jason (large)" => fn ->
      data = BenchmarkData.large_map()
      json = Jason.encode!(data)
      Jason.decode!(json)
    end
  },
  time: 5,
  memory_time: 2,
  formatters: [
    {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
  ]
)

IO.puts("")
IO.puts("=" |> String.duplicate(80))
IO.puts("Benchmark Complete!")
IO.puts("=" |> String.duplicate(80))
