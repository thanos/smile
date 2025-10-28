# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-28

### Added

#### Performance Benchmarking
- Added comprehensive benchmark suite comparing SmileEx with Jason using Benchee 1.5.0
- **Three benchmark scripts** in `benchmarks/` directory:
  - `comparison.exs` - Full performance comparison (encoding, decoding, round-trip, memory usage)
  - `size_comparison.exs` - Detailed message size analysis with color-coded results
  - `quick.exs` - Fast benchmark for development
- Benchmark documentation in `benchmarks/README.md` with usage examples and interpretation guide
- Size comparison showing 12-60% reduction depending on data structure
- Performance metrics showing Jason is faster for small payloads, SmileEx competitive for large datasets

#### Property-Based Testing
- Added property-based testing using StreamData 1.1
- **24 comprehensive property tests** (`test/smile_property_test.exs`) covering:
  - Round-trip encoding/decoding for all data types
  - Type preservation (integers, floats, strings, booleans, nil, lists, maps)
  - Header validity for all encoded data
  - Deterministic encoding
  - Encoding options correctness (`shared_names`, `shared_values`)
  - Size optimization properties
  - Edge cases (Unicode, special characters, large values, nested structures)
  - Error handling
- Custom data generators for Smile-compatible types
- Recursive generator for nested structures (depth-limited)
- **~2,400 test cases** generated per test run
- Comprehensive documentation in `test/property_testing_guide.md`
- Implementation summary in `PROPERTY_TESTING.md`

#### Documentation
- Added `benchmarks/README.md` - Comprehensive benchmarking guide
- Added `test/property_testing_guide.md` - Property testing guide with examples
- Added `PROPERTY_TESTING.md` - Property testing implementation summary
- Updated main `README.md` with:
  - Benchmarking section with usage examples
  - Property-based testing section
  - Detailed size reduction statistics
  - Best use cases for Smile vs JSON

### Changed

#### Code Quality Improvements
- **Reduced cyclomatic complexity** across multiple functions:
  - `Smile.Decoder.decode_value` - Split into smaller functions using pattern matching
  - `Smile.Encoder.encode_string` - Extracted helper functions for value sharing
  - `Smile.Encoder.encode_string_bytes` - Split into ASCII and Unicode encoders
  - `Smile.Decoder.decode_string_value` - Extracted long string handler
- **Reduced nesting depth** using `with` statements:
  - `Smile.Decoder.decode_long_string` - Uses `with` for cleaner error handling
  - `Smile.Decoder.decode_long_field_name` - Uses `with` for cleaner error handling
- Extracted helper functions for better separation of concerns:
  - `split_at_string_terminator/1`
  - `split_at_field_name_terminator/1`
  - `maybe_add_shared_value/2`
  - `maybe_add_shared_name/2`
  - `encode_ascii_string/2`
  - `encode_unicode_string/2`
  - `decode_value_by_token/3`
  - `decode_long_string_or_reference/3`
- Fixed alias ordering to be alphabetical
- Converted single-condition `cond` to `if-else` in property tests
- **Zero Credo issues** - All code quality checks passing

### Dependencies

- Added `{:benchee, "~> 1.5.0", only: :dev, runtime: false}` - For performance benchmarking
- Added `{:jason, "~> 1.4", only: [:dev, :test]}` - For comparison benchmarks
- Added `{:stream_data, "~> 1.1", only: :test}` - For property-based testing

### Testing

- Increased from **56 tests** to **80 tests** (5 doctests + 24 properties + 51 unit tests)
- Test coverage improved to **83.5%** (from 82.8%)
- All tests passing with zero failures
- Property tests automatically generate thousands of test cases
- Added tests for edge cases discovered through property testing

### Performance

- Benchmarks show typical **12-60% size reduction** vs JSON:
  - Best: 60%+ for large datasets with consistent structure (product catalogs, logs)
  - Good: 30-50% for API responses with multiple records
  - Modest: 10-20% for simple objects and short strings
- Encoding speed: Jason faster for small payloads, SmileEx competitive for large datasets
- Memory usage: SmileEx uses more memory due to shared reference tracking

## [0.1.0] - 2025-10-26

### Added

- Initial release of SmileEx binary format encoder/decoder for Elixir
- Complete implementation of Smile format specification v1.0
- Support for all JSON-compatible data types (null, boolean, integer, float, string, array, object)
- Encoding with back-references for field names and string values
- Configurable encoding options (shared_names, shared_values, raw_binary)
- Both tuple-based (`encode/2`, `decode/1`) and exception-based (`encode!/2`, `decode!/1`) APIs
- Comprehensive test suite with 56 tests
- Full documentation with examples
- Variable-length integer encoding (VInt) support
- ZigZag encoding for signed integers
- Optimized string encoding based on length and character set (ASCII vs Unicode)
- Support for small integer optimization (single-byte encoding for -16 to +15)

### Features

- Encodes Elixir terms to Smile binary format
- Decodes Smile binary format to Elixir terms
- Perfect round-trip encoding/decoding preservation
- Typically 20-40% size reduction compared to JSON
- Faster encoding and decoding than text-based JSON

[0.2.0]: https://github.com/thanos/smile_ex/releases/tag/v0.2.0
[0.1.0]: https://github.com/thanos/smile_ex/releases/tag/v0.1.0

