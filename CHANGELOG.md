# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-26

### Added

- Initial release of Smile binary format encoder/decoder for Elixir
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

[0.1.0]: https://github.com/thanos/smile/releases/tag/v0.1.0

