defmodule Smile.Constants do
  @moduledoc """
  Defines constants for the Smile binary format specification.

  This module contains all token types, byte markers, and configuration values
  defined in the official Smile format specification. These constants are used
  by the encoder and decoder to ensure proper format compliance.

  ## Header Constants

  The Smile format starts with a 4-byte header:

    * Byte 1: `0x3A` (ASCII ':')
    * Byte 2: `0x29` (ASCII ')')
    * Byte 3: `0x0A` (ASCII '\\n')
    * Byte 4: Version and flags byte

  This creates the recognizable `:)\\n` signature.

  ## Token Types

  The format defines various token types for different data:

    * Literal tokens (null, true, false, empty string)
    * Integer tokens (small int, 32-bit, 64-bit)
    * Float tokens (32-bit, 64-bit)
    * String tokens (tiny, small, long; ASCII and Unicode variants)
    * Structural tokens (array start/end, object start/end)
    * Back-reference tokens (shared names and values)

  ## Optimization Limits

  The format defines limits for various optimizations:

    * Maximum 1024 shared field names
    * Maximum 1024 shared string values
    * Maximum 64 bytes for short string values eligible for sharing
    * Maximum 56 bytes for short field names in Unicode

  ## References

  Based on the official specification:
  https://github.com/FasterXML/smile-format-specification
  """

  # Thresholds
  def max_short_value_string_bytes, do: 64
  def max_short_name_ascii_bytes, do: 64
  def max_short_name_unicode_bytes, do: 56
  def max_shared_names, do: 1024
  def max_shared_string_values, do: 1024
  def max_shared_string_length_bytes, do: 65
  def min_buffer_for_possible_short_string, do: 1 + 3 * 65

  # Byte markers
  def byte_marker_end_of_string, do: 0xFC
  def byte_marker_end_of_content, do: 0xFF

  # Format header
  # ':'
  def header_byte_1, do: 0x3A
  # ')'
  def header_byte_2, do: 0x29
  # '\n'
  def header_byte_3, do: 0x0A
  # version 0
  def header_byte_4, do: 0x00

  # Header bits
  def header_bit_has_shared_names, do: 0x01
  def header_bit_has_shared_string_values, do: 0x02
  def header_bit_has_raw_binary, do: 0x04

  # Type prefixes
  def token_prefix_integer, do: 0x24
  def token_prefix_fp, do: 0x28
  def token_prefix_shared_string_short, do: 0x00
  def token_prefix_shared_string_long, do: 0xEC
  def token_prefix_tiny_ascii, do: 0x40
  def token_prefix_small_ascii, do: 0x60
  def token_prefix_tiny_unicode, do: 0x80
  def token_prefix_short_unicode, do: 0xA0
  def token_prefix_small_int, do: 0xC0
  def token_prefix_misc_other, do: 0xE0

  # Token literals
  def token_literal_empty_string, do: 0x20
  def token_literal_null, do: 0x21
  def token_literal_false, do: 0x22
  def token_literal_true, do: 0x23
  def token_literal_start_array, do: 0xF8
  def token_literal_end_array, do: 0xF9
  def token_literal_start_object, do: 0xFA
  def token_literal_end_object, do: 0xFB

  # Misc text/binary types
  def token_misc_long_text_ascii, do: 0xE0
  def token_misc_long_text_unicode, do: 0xE4
  def token_misc_binary_7bit, do: 0xE8
  def token_misc_binary_raw, do: 0xFD

  # Numeric modifiers
  def token_misc_integer_32, do: 0x00
  def token_misc_integer_64, do: 0x01
  def token_misc_integer_big, do: 0x02
  def token_misc_float_32, do: 0x00
  def token_misc_float_64, do: 0x01
  def token_misc_float_big, do: 0x02

  # Token types for keys
  def token_key_empty_string, do: 0x20
  def token_prefix_key_shared_long, do: 0x30
  def token_key_long_string, do: 0x34
  def token_prefix_key_shared_short, do: 0x40
  def token_prefix_key_ascii, do: 0x80
  def token_prefix_key_unicode, do: 0xC0

  # Token byte combinations
  def token_byte_int_32, do: token_prefix_integer() + token_misc_integer_32()
  def token_byte_int_64, do: token_prefix_integer() + token_misc_integer_64()
  def token_byte_float_32, do: token_prefix_fp() + token_misc_float_32()
  def token_byte_float_64, do: token_prefix_fp() + token_misc_float_64()
end
