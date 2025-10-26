# Smile

[![Hex.pm](https://img.shields.io/hexpm/v/smile.svg)](https://hex.pm/packages/smile)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/smile/)
[![Hex.pm](https://img.shields.io/hexpm/dt/smile.svg)](https://hex.pm/packages/smile)
[![Hex.pm](https://img.shields.io/hexpm/l/smile.svg)](https://github.com/thanos/smile/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/thanos/smile.svg?branch=master)](https://travis-ci.org/thanos/smile)

An Elixir library for encoding and decoding data using the [Smile binary data interchange format](https://en.wikipedia.org/wiki/Smile_%28data_interchange_format%29).

Smile is a computer data interchange format based on JSON. It can be considered a binary serialization of the generic JSON data model, which means that tools that operate on JSON may be used with Smile as well, as long as a proper encoder/decoder exists. The format is more compact and more efficient to process than text-based JSON. It was designed by [FasterXML](https://github.com/FasterXML/smile-format-specification) as a drop-in replacement for JSON with better performance characteristics.

## Features

- **Fast**: Binary format is more efficient to encode/decode than JSON
- **Compact**: Smaller payload sizes compared to JSON (typically 20-40% size reduction)
- **Back References**: Optional support for shared property names and string values to reduce redundancy
- **Type Preserving**: Maintains data types (integers, floats, strings, booleans, null, arrays, objects)
- **JSON Compatible**: Can be used anywhere JSON is used (with proper encoder/decoder)
- **Self-Describing**: Files start with `:)\n` header (the "smiley" signature) for easy identification

## Installation

Add `smile` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:smile, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Encoding

```elixir
# Encode a simple value
iex> Smile.encode("hello")
{:ok, <<58, 41, 10, 3, 68, 104, 101, 108, 108, 111>>}

# Encode a map
iex> data = %{"name" => "Alice", "age" => 30, "active" => true}
iex> {:ok, binary} = Smile.encode(data)
{:ok, <<58, 41, 10, 3, 250, ...>>}

# Encode with options
iex> Smile.encode(data, shared_names: true, shared_values: true)
{:ok, <<58, 41, 10, 3, 250, ...>>}

# Use encode! for exception-based error handling
iex> binary = Smile.encode!(data)
<<58, 41, 10, 3, 250, ...>>
```

### Decoding

```elixir
# Decode binary data
iex> {:ok, decoded} = Smile.decode(binary)
{:ok, %{"name" => "Alice", "age" => 30, "active" => true}}

# Use decode! for exception-based error handling
iex> decoded = Smile.decode!(binary)
%{"name" => "Alice", "age" => 30, "active" => true}
```

## Supported Data Types

Smile supports encoding and decoding of the following Elixir types:

| Elixir Type | Smile Type | Example |
|-------------|------------|---------|
| `nil` | Null | `nil` |
| `true`, `false` | Boolean | `true` |
| Integer | Integer | `42`, `-16`, `999_999_999` |
| Float | Float | `3.14159`, `-2.71828` |
| String (Binary) | String | `"hello"`, `"世界"` |
| List | Array | `[1, 2, 3]`, `["a", "b"]` |
| Map | Object | `%{"key" => "value"}` |
| Atom | String | `:atom` → `"atom"` |

## Encoding Options

The `encode/2` function accepts the following options:

- `:shared_names` (boolean, default: `true`) - Enable back references for field names to reduce redundancy when the same keys appear multiple times
- `:shared_values` (boolean, default: `true`) - Enable back references for short string values (≤64 bytes) to reduce redundancy
- `:raw_binary` (boolean, default: `false`) - Allow raw binary values in the output

### Example with Options

```elixir
# Disable shared references for simpler output
Smile.encode(data, shared_names: false, shared_values: false)

# Enable all optimizations
Smile.encode(data, shared_names: true, shared_values: true)
```

## Format Details

Smile format uses a 4-byte header:
1. Byte 1: `0x3A` (`:`)
2. Byte 2: `0x29` (`)`)
3. Byte 3: `0x0A` (`\n`)
4. Byte 4: Version and flags

This creates the recognizable `:)\n` signature at the start of every Smile file.

## Complex Examples

### Nested Structures

```elixir
data = %{
  "user" => %{
    "name" => "Alice",
    "email" => "alice@example.com",
    "profile" => %{
      "age" => 30,
      "interests" => ["coding", "reading", "hiking"]
    }
  },
  "timestamp" => 1234567890
}

{:ok, encoded} = Smile.encode(data)
{:ok, decoded} = Smile.decode(encoded)

# Data is perfectly preserved
decoded == data
# => true
```

### Arrays of Objects

```elixir
users = [
  %{"name" => "Alice", "score" => 95},
  %{"name" => "Bob", "score" => 87},
  %{"name" => "Charlie", "score" => 92}
]

{:ok, encoded} = Smile.encode(users, shared_names: true)
{:ok, decoded} = Smile.decode(encoded)

# Shared names optimization reduces size when same keys repeat
decoded == users
# => true
```

## Performance Benefits

Smile provides several advantages over JSON:

1. **Smaller Size**: Binary encoding is more compact than text
2. **Faster Processing**: No need to parse text, direct binary operations
3. **Back References**: Repeated keys/values are stored once and referenced
4. **Type Efficiency**: Native binary representation of numbers

## Use Cases

Smile is ideal for:

- API communication where bandwidth is a concern
- Storing structured data in databases
- Inter-service communication in microservices
- Caching serialized data
- Log aggregation and storage
- Any scenario where JSON is used but performance/size matters

## Comparison with JSON

```elixir
data = %{"users" => [%{"name" => "Alice"}, %{"name" => "Bob"}]}

# JSON (using Poison or Jason)
json = Jason.encode!(data)
# => "{\"users\":[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]}"
# Size: 47 bytes

# Smile
{:ok, smile} = Smile.encode(data)
# Size: ~35 bytes (approximately 25% smaller)
# Plus: faster to encode/decode
```

## Testing

Run the test suite:

```bash
mix test
```

Run tests with coverage:

```bash
mix test --cover
```

## Specification

This implementation is based on the official [Smile format specification](https://github.com/FasterXML/smile-format-specification).

For more details about the format, see:
- [Smile Format Specification](https://github.com/FasterXML/smile-format-specification)
- [Wikipedia: Smile (data interchange format)](https://en.wikipedia.org/wiki/Smile_%28data_interchange_format%29)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## API Documentation

The complete API documentation is available on [HexDocs](https://hexdocs.pm/smile/).

You can also generate documentation locally:

```bash
mix docs
```

The documentation will be generated in the `doc/` directory.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

