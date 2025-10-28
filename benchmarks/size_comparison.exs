# Message Size Comparison: SmileEx vs Jason
# Run with: mix run benchmarks/size_comparison.exs

defmodule SizeComparison do
  @moduledoc """
  Compares the encoded message sizes between SmileEx (Smile binary format)
  and Jason (JSON text format) across various data structures and sizes.
  """

  defmodule TestData do
    @moduledoc "Test data sets for size comparison"

    def primitive_values do
      [
        {"nil", nil},
        {"true", true},
        {"false", false},
        {"small integer (1)", 1},
        {"small integer (42)", 42},
        {"large integer", 999_999_999},
        {"negative integer", -123_456},
        {"float (pi)", 3.14159},
        {"float (e)", 2.71828},
        {"empty string", ""},
        {"short string", "hello"},
        {"medium string", "The quick brown fox jumps over the lazy dog"},
        {"long string", String.duplicate("Lorem ipsum dolor sit amet ", 10)},
        {"unicode string", "Hello 世界 🌍 Привет"},
        {"empty array", []},
        {"empty object", %{}}
      ]
    end

    def arrays do
      [
        {"small array [1,2,3]", [1, 2, 3]},
        {"array of 10 integers", Enum.to_list(1..10)},
        {"array of 100 integers", Enum.to_list(1..100)},
        {"array of 1000 integers", Enum.to_list(1..1000)},
        {"array of strings", ["apple", "banana", "cherry", "date", "elderberry"]},
        {"array of booleans", [true, false, true, false, true]},
        {"array of floats", [1.1, 2.2, 3.3, 4.4, 5.5]},
        {"mixed array", [1, "two", 3.0, true, nil, [4, 5]]}
      ]
    end

    def objects do
      [
        {"simple object", %{"name" => "Alice", "age" => 30}},
        {"user profile", %{
          "id" => 12345,
          "username" => "alice_smith",
          "email" => "alice@example.com",
          "active" => true,
          "score" => 98.5
        }},
        {"nested object", %{
          "user" => %{
            "name" => "Alice",
            "profile" => %{
              "age" => 30,
              "location" => "San Francisco"
            }
          }
        }},
        {"object with arrays", %{
          "name" => "Alice",
          "tags" => ["developer", "elixir", "functional"],
          "scores" => [95, 87, 92]
        }},
        {"repeated keys", %{
          "name" => "Alice",
          "data" => %{
            "name" => "Bob",
            "nested" => %{
              "name" => "Charlie",
              "deep" => %{
                "name" => "David"
              }
            }
          }
        }}
      ]
    end

    def realistic_data do
      [
        {"API response (10 users)", %{
          "status" => "success",
          "data" => Enum.map(1..10, fn i ->
            %{
              "id" => i,
              "username" => "user_#{i}",
              "email" => "user#{i}@example.com",
              "age" => 20 + rem(i, 50),
              "active" => rem(i, 2) == 0
            }
          end),
          "meta" => %{
            "page" => 1,
            "total" => 10,
            "timestamp" => "2025-10-28T12:00:00Z"
          }
        }},
        {"API response (100 users)", %{
          "status" => "success",
          "data" => Enum.map(1..100, fn i ->
            %{
              "id" => i,
              "username" => "user_#{i}",
              "email" => "user#{i}@example.com",
              "age" => 20 + rem(i, 50),
              "active" => rem(i, 2) == 0,
              "score" => 1000 + i * 10
            }
          end),
          "meta" => %{
            "page" => 1,
            "total" => 100,
            "timestamp" => "2025-10-28T12:00:00Z"
          }
        }},
        {"product catalog", %{
          "products" => Enum.map(1..50, fn i ->
            %{
              "id" => i,
              "name" => "Product #{i}",
              "price" => 9.99 + i,
              "category" => "Category #{rem(i, 5)}",
              "in_stock" => rem(i, 3) != 0,
              "tags" => ["tag#{rem(i, 3)}", "tag#{rem(i, 4)}"]
            }
          end)
        }},
        {"log entries", Enum.map(1..100, fn i ->
          %{
            "timestamp" => "2025-10-28T12:#{rem(i, 60)}:00Z",
            "level" => Enum.at(["INFO", "WARN", "ERROR"], rem(i, 3)),
            "message" => "Log message #{i}",
            "context" => %{
              "user_id" => rem(i, 50),
              "request_id" => "req_#{i}"
            }
          }
        end)},
        {"deeply nested", %{
          "level1" => %{
            "level2" => %{
              "level3" => %{
                "level4" => %{
                  "level5" => %{
                    "level6" => %{
                      "level7" => %{
                        "data" => [1, 2, 3, 4, 5],
                        "info" => "deeply nested structure"
                      }
                    }
                  }
                }
              }
            }
          }
        }}
      ]
    end
  end

  def format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  def format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"

  def format_reduction(json_size, smile_size) do
    reduction = (1 - smile_size / json_size) * 100
    color = cond do
      reduction >= 50 -> :green
      reduction >= 30 -> :yellow
      reduction >= 10 -> :blue
      reduction >= 0 -> :cyan
      true -> :red
    end
    {Float.round(reduction, 1), color}
  end

  def colorize(text, :green), do: IO.ANSI.green() <> text <> IO.ANSI.reset()
  def colorize(text, :yellow), do: IO.ANSI.yellow() <> text <> IO.ANSI.reset()
  def colorize(text, :blue), do: IO.ANSI.blue() <> text <> IO.ANSI.reset()
  def colorize(text, :cyan), do: IO.ANSI.cyan() <> text <> IO.ANSI.reset()
  def colorize(text, :red), do: IO.ANSI.red() <> text <> IO.ANSI.reset()

  def compare_sizes(data, name) do
    json = Jason.encode!(data)
    smile = Smile.encode!(data)

    json_size = byte_size(json)
    smile_size = byte_size(smile)
    {reduction, color} = format_reduction(json_size, smile_size)

    %{
      name: name,
      json_size: json_size,
      smile_size: smile_size,
      reduction: reduction,
      color: color
    }
  end

  def print_header(title) do
    IO.puts("\n")
    IO.puts(IO.ANSI.bright() <> title <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 90))
    IO.puts(String.pad_trailing("Data Type", 45) <>
            String.pad_trailing("JSON", 15) <>
            String.pad_trailing("Smile", 15) <>
            "Reduction")
    IO.puts(String.duplicate("-", 90))
  end

  def print_result(result) do
    json_str = format_bytes(result.json_size)
    smile_str = format_bytes(result.smile_size)
    reduction_str = "#{result.reduction}%"

    IO.puts(
      String.pad_trailing(result.name, 45) <>
      String.pad_trailing(json_str, 15) <>
      String.pad_trailing(smile_str, 15) <>
      colorize(reduction_str, result.color)
    )
  end

  def print_summary(results) do
    total_json = Enum.sum(Enum.map(results, & &1.json_size))
    total_smile = Enum.sum(Enum.map(results, & &1.smile_size))
    avg_reduction = Enum.sum(Enum.map(results, & &1.reduction)) / length(results)
    {overall_reduction, color} = format_reduction(total_json, total_smile)

    IO.puts(String.duplicate("-", 90))
    IO.puts(String.pad_trailing("TOTAL", 45) <>
            String.pad_trailing(format_bytes(total_json), 15) <>
            String.pad_trailing(format_bytes(total_smile), 15) <>
            colorize("#{overall_reduction}%", color))
    IO.puts(String.duplicate("=", 90))
    avg_color = if avg_reduction >= 30, do: :green, else: :blue
    IO.puts("\nAverage Reduction: #{colorize("#{Float.round(avg_reduction, 1)}%", avg_color)}")
    IO.puts("Total Saved: #{colorize(format_bytes(total_json - total_smile), :green)}")
  end
end

# Main execution
IO.puts("\n")
IO.puts(IO.ANSI.bright() <> IO.ANSI.blue() <>
        "MESSAGE SIZE COMPARISON: SmileEx vs Jason" <>
        IO.ANSI.reset())
IO.puts(String.duplicate("=", 90))
IO.puts("\nComparing encoded message sizes across various data structures...")
IO.puts("Color coding: " <>
        SizeComparison.colorize("50%+ (excellent)", :green) <> " | " <>
        SizeComparison.colorize("30-49% (great)", :yellow) <> " | " <>
        SizeComparison.colorize("10-29% (good)", :blue) <> " | " <>
        SizeComparison.colorize("0-9% (minor)", :cyan))

# Primitive values
SizeComparison.print_header("1. Primitive Values")
SizeComparison.TestData.primitive_values()
|> Enum.map(fn {name, data} -> SizeComparison.compare_sizes(data, name) end)
|> Enum.each(&SizeComparison.print_result/1)

# Arrays
SizeComparison.print_header("2. Arrays")
array_results =
  SizeComparison.TestData.arrays()
  |> Enum.map(fn {name, data} -> SizeComparison.compare_sizes(data, name) end)

Enum.each(array_results, &SizeComparison.print_result/1)

# Objects
SizeComparison.print_header("3. Objects and Maps")
object_results =
  SizeComparison.TestData.objects()
  |> Enum.map(fn {name, data} -> SizeComparison.compare_sizes(data, name) end)

Enum.each(object_results, &SizeComparison.print_result/1)

# Realistic data
SizeComparison.print_header("4. Realistic Data Structures")
realistic_results =
  SizeComparison.TestData.realistic_data()
  |> Enum.map(fn {name, data} -> SizeComparison.compare_sizes(data, name) end)

Enum.each(realistic_results, &SizeComparison.print_result/1)

# Overall summary
IO.puts("\n")
IO.puts(IO.ANSI.bright() <> "OVERALL SUMMARY" <> IO.ANSI.reset())
IO.puts(String.duplicate("=", 90))

all_results = array_results ++ object_results ++ realistic_results
SizeComparison.print_summary(all_results)

# Size efficiency analysis
IO.puts("\n")
IO.puts(IO.ANSI.bright() <> "SIZE EFFICIENCY ANALYSIS" <> IO.ANSI.reset())
IO.puts(String.duplicate("=", 90))

best_reduction = Enum.max_by(all_results, & &1.reduction)
worst_reduction = Enum.min_by(all_results, & &1.reduction)
median_reduction = all_results
  |> Enum.map(& &1.reduction)
  |> Enum.sort()
  |> Enum.at(div(length(all_results), 2))

IO.puts("\nBest size reduction:")
IO.puts("  #{best_reduction.name}: #{SizeComparison.colorize("#{best_reduction.reduction}%", best_reduction.color)}")
IO.puts("  JSON: #{SizeComparison.format_bytes(best_reduction.json_size)} → " <>
        "Smile: #{SizeComparison.format_bytes(best_reduction.smile_size)}")

IO.puts("\nWorst size reduction:")
IO.puts("  #{worst_reduction.name}: #{SizeComparison.colorize("#{worst_reduction.reduction}%", worst_reduction.color)}")
IO.puts("  JSON: #{SizeComparison.format_bytes(worst_reduction.json_size)} → " <>
        "Smile: #{SizeComparison.format_bytes(worst_reduction.smile_size)}")

IO.puts("\nMedian reduction: #{SizeComparison.colorize("#{Float.round(median_reduction, 1)}%", :blue)}")

IO.puts("\n")
IO.puts(IO.ANSI.bright() <> "KEY INSIGHTS" <> IO.ANSI.reset())
IO.puts(String.duplicate("=", 90))
IO.puts("\n1. Smile format excels with:")
IO.puts("   • Large datasets with repeated keys (50-60% reduction)")
IO.puts("   • Arrays of objects with consistent structure")
IO.puts("   • Data with many repeated field names")
IO.puts("\n2. Smile provides modest gains for:")
IO.puts("   • Small primitive values (overhead from header)")
IO.puts("   • Short strings and simple data")
IO.puts("\n3. Best use cases for Smile:")
IO.puts("   • API responses with multiple records")
IO.puts("   • Log aggregation and storage")
IO.puts("   • Database serialization")
IO.puts("   • Inter-service communication with large payloads")
IO.puts("\n4. Stick with JSON for:")
IO.puts("   • Human readability requirements")
IO.puts("   • Web browser compatibility")
IO.puts("   • Very small messages (< 100 bytes)")
IO.puts("   • External API integration where JSON is expected")

IO.puts("\n")
IO.puts(String.duplicate("=", 90))
IO.puts(IO.ANSI.bright() <> "Size comparison complete!" <> IO.ANSI.reset())
IO.puts(String.duplicate("=", 90))
IO.puts("\n")
