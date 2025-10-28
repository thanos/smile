# Property-Based Testing Guide for SmileEx

This guide explains the property-based testing approach used in SmileEx and how to extend it.

## What is Property-Based Testing?

Property-based testing (also known as generative testing) is a testing approach where you:

1. **Define properties** that should always hold true
2. **Generate random test cases** automatically
3. **Verify properties** hold for all generated cases
4. **Shrink failures** to find minimal failing examples

Instead of writing specific test cases, you write general properties that should be true for all valid inputs.

## Why Property-Based Testing for SmileEx?

SmileEx is a serialization library that needs to work correctly for:
- All data types (integers, floats, strings, booleans, nil, lists, maps)
- All value ranges (small integers, large integers, edge cases)
- All string contents (ASCII, Unicode, special characters)
- Nested structures of arbitrary depth
- Various encoding options

It's impractical to manually write test cases for all combinations. Property-based testing automatically generates thousands of test cases covering edge cases we might not think of.

## Properties Tested

### 1. Round-Trip Property
**Property**: `encode(data) |> decode() == data`

The most fundamental property: encoding and then decoding should return the original data.

```elixir
property "encoding and decoding preserves data" do
  check all data <- smile_data(0), max_runs: 100 do
    {:ok, encoded} = Smile.encode(data)
    {:ok, decoded} = Smile.decode(encoded)
    assert decoded == data
  end
end
```

### 2. Type Preservation
**Property**: Types are preserved through the round-trip

```elixir
property "integers remain integers after round-trip" do
  check all int <- smile_integer(), max_runs: 100 do
    {:ok, encoded} = Smile.encode(int)
    {:ok, decoded} = Smile.decode(encoded)
    assert is_integer(decoded)
    assert decoded == int
  end
end
```

### 3. Header Validity
**Property**: All encoded data must start with the Smile header

```elixir
property "all encoded data starts with Smile header" do
  check all data <- smile_data(0), max_runs: 100 do
    {:ok, encoded} = Smile.encode(data)
    assert <<0x3A, 0x29, 0x0A, _flags::8, _rest::binary>> = encoded
  end
end
```

### 4. Deterministic Encoding
**Property**: Encoding the same data multiple times produces the same result

```elixir
property "encoding is deterministic" do
  check all data <- smile_primitive(), max_runs: 100 do
    {:ok, encoded1} = Smile.encode(data)
    {:ok, encoded2} = Smile.encode(data)
    assert encoded1 == encoded2
  end
end
```

### 5. Options Don't Affect Correctness
**Property**: Encoding options (like `shared_names`) may affect size but not correctness

```elixir
property "shared_names option doesn't affect decoded result" do
  check all map <- smile_map(smile_integer(), 10), max_runs: 50 do
    {:ok, encoded_with} = Smile.encode(map, shared_names: true)
    {:ok, encoded_without} = Smile.encode(map, shared_names: false)
    
    {:ok, decoded_with} = Smile.decode(encoded_with)
    {:ok, decoded_without} = Smile.decode(encoded_without)
    
    assert decoded_with == decoded_without
  end
end
```

### 6. Size Optimization Properties
**Property**: `shared_names` should not increase size

```elixir
property "shared_names reduces size for repeated keys" do
  check all data <- nested_data_with_repeated_keys(), max_runs: 50 do
    {:ok, with_shared} = Smile.encode(data, shared_names: true)
    {:ok, without_shared} = Smile.encode(data, shared_names: false)
    assert byte_size(with_shared) <= byte_size(without_shared)
  end
end
```

## Data Generators

SmileEx uses custom generators to create valid test data:

### Primitive Generators

```elixir
# Strings: ASCII, Unicode, special characters
defp smile_string do
  StreamData.one_of([
    StreamData.string(:alphanumeric, min_length: 0, max_length: 100),
    StreamData.string(:printable, min_length: 0, max_length: 50)
  ])
end

# Integers: small, 32-bit, large
defp smile_integer do
  StreamData.one_of([
    StreamData.integer(-16..15),
    StreamData.integer(-2_147_483_648..2_147_483_647)
  ])
end

# Floats
defp smile_float do
  StreamData.float(min: -1000.0, max: 1000.0)
end
```

### Composite Generators

```elixir
# Lists
defp smile_list(element_generator, max_size) do
  StreamData.list_of(element_generator, max_length: max_size)
end

# Maps with string keys
defp smile_map(value_generator, max_size) do
  StreamData.map_of(
    smile_string(),
    value_generator,
    max_length: max_size
  )
end
```

### Recursive Generator for Nested Structures

```elixir
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
```

## Running Property Tests

Run all property tests:
```bash
mix test test/smile_property_test.exs
```

Run with more iterations (default is 100):
```elixir
property "my property" do
  check all data <- generator(), max_runs: 1000 do
    # assertions
  end
end
```

Run with specific seed to reproduce a failure:
```bash
mix test --seed 12345 test/smile_property_test.exs
```

## Understanding Test Output

### Successful Run
```
........................
Finished in 0.5 seconds
24 properties, 0 failures
```

### Failure with Shrinking
When a property fails, StreamData automatically shrinks the failing case to find the minimal example:

```
Failed with generated values (after 45 successful runs):

  * Clause:    value <- smile_integer()
    Generated: -2147483648

Assertion failed
code:  assert encoded_size < 100
left:  256
```

This shows:
- The property succeeded 45 times before failing
- The minimal failing value is `-2147483648`
- The assertion that failed
- The actual values involved

## Adding New Properties

To add a new property test:

1. **Identify a property** that should always hold
2. **Create appropriate generators** for the test data
3. **Write the property test** using the `property` macro
4. **Run and verify** the test passes

Example:

```elixir
property "encoded size is never zero" do
  check all data <- smile_data(0), max_runs: 100 do
    {:ok, encoded} = Smile.encode(data)
    assert byte_size(encoded) > 0
  end
end
```

## Best Practices

### 1. Keep Generators Focused
Don't generate data that can't be handled:

```elixir
# BAD: Generates values outside valid range
StreamData.integer()

# GOOD: Limited to supported range
StreamData.integer(-999_999_999..999_999_999)
```

### 2. Limit Recursion Depth
Prevent infinite or very deep structures:

```elixir
defp smile_data(depth) when depth >= 3 do
  smile_primitive()  # Stop recursion
end
```

### 3. Handle Floats Specially
Use `assert_in_delta` for floating-point comparisons:

```elixir
if is_float(value) do
  assert_in_delta decoded, value, 0.000001
else
  assert decoded == value
end
```

### 4. Use Appropriate Max Runs
Balance between coverage and test speed:
- **50-100 runs**: Quick tests for CI
- **200-500 runs**: Thorough local testing
- **1000+ runs**: Stress testing before releases

### 5. Avoid Filters When Possible
Instead of filtering, restructure generators:

```elixir
# BAD: Filters too many values
check all str <- smile_string(), str != "", max_runs: 50

# GOOD: Generate non-empty strings directly
non_empty = StreamData.string(:alphanumeric, min_length: 1, max_length: 20)
check all str <- non_empty, max_runs: 50
```

## Comparing with Traditional Tests

### Traditional Unit Test
```elixir
test "encodes integers" do
  assert {:ok, _} = Smile.encode(0)
  assert {:ok, _} = Smile.encode(42)
  assert {:ok, _} = Smile.encode(-100)
end
```

Tests 3 specific cases.

### Property Test
```elixir
property "encodes all integers" do
  check all int <- smile_integer(), max_runs: 100 do
    assert {:ok, _} = Smile.encode(int)
  end
end
```

Tests 100 random cases, including edge cases.

## Coverage Statistics

Current property test coverage:
- **24 properties** covering core functionality
- **~2,400 test cases** generated per full test run
- Tests primitives, collections, nested structures
- Tests encoding options and optimizations
- Tests error cases and edge conditions

## Resources

- [StreamData Documentation](https://hexdocs.pm/stream_data/)
- [Property-Based Testing with PropEr, Erlang, and Elixir](https://pragprog.com/titles/fhproper/property-based-testing-with-proper-erlang-and-elixir/)
- [Introduction to Property-Based Testing](https://propertesting.com/)

## Contributing

When adding new features to SmileEx:

1. Write property tests for the new functionality
2. Ensure existing properties still pass
3. Document any new generators or patterns used
4. Update this guide if introducing new testing approaches

