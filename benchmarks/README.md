# SmileEx vs Jason Benchmarks

This directory contains benchmark scripts comparing the performance of SmileEx (Smile binary format) with Jason (JSON format).

## Running the Benchmarks

### Full Performance Comparison
```bash
mix run benchmarks/comparison.exs
```

This runs a comprehensive performance comparison including:
- Encoding benchmarks (small, medium, large datasets)
- Decoding benchmarks
- Round-trip benchmarks (encode + decode)
- Size comparison analysis
- Memory usage statistics

### Message Size Comparison
```bash
mix run benchmarks/size_comparison.exs
```

This benchmark focuses specifically on comparing message sizes between JSON and Smile formats:
- Primitive values (integers, floats, strings, booleans, nil)
- Arrays (various sizes and types)
- Objects and maps (simple, nested, repeated keys)
- Realistic data structures (API responses, product catalogs, logs)
- Color-coded results showing reduction percentages
- Detailed analysis of best/worst cases
- Key insights and recommendations

### Quick Comparison
```bash
mix run benchmarks/quick.exs
```

A faster benchmark focusing on common use cases.

## Key Findings

### Size Reduction
Smile format typically achieves:
- **12-18%** reduction for small data structures
- **40-60%** reduction for large datasets with repeated keys
- Better compression with shared names and values enabled

### Performance Trade-offs

**Jason (JSON) is faster for:**
- Small payloads (< 1KB)
- Simple data structures
- When text format is required
- Integration with web APIs

**SmileEx (Smile) excels at:**
- Large datasets (> 10KB)
- Binary data transmission
- Storage optimization
- Data with repeated field names

### Memory Usage
- SmileEx uses more memory during processing due to shared references tracking
- Jason is more memory-efficient for simple encoding/decoding
- For large-scale applications, consider the size vs speed trade-off

## Understanding the Results

### IPS (Iterations Per Second)
Higher is better. Shows how many operations can be performed per second.

### Average Time
Lower is better. Shows the average time per operation.

### Memory Usage
Lower is better. Shows memory allocated during operations.

## Customizing Benchmarks

You can modify the test data in `comparison.exs` or create your own benchmark scripts using the Benchee library:

```elixir
Benchee.run(%{
  "SmileEx encode" => fn -> Smile.encode!(your_data) end,
  "Jason encode" => fn -> Jason.encode!(your_data) end
}, time: 5, memory_time: 2)
```

## Dependencies

- `benchee ~> 1.5.0` - Benchmarking library
- `jason ~> 1.4` - JSON encoder/decoder for comparison

