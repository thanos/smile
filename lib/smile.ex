defmodule Smile do
  @moduledoc """
  Smile is a binary data interchange format based on JSON.

  It provides efficient encoding and decoding of Elixir data structures
  to and from the Smile binary format, which is more compact and faster
  to process than JSON.

  ## Features

  - **Binary Format**: More compact than JSON text format
  - **Back References**: Optional support for shared property names and string values
  - **Type Safe**: Preserves data types (integers, floats, strings, arrays, objects)
  - **Fast Processing**: More efficient encoding and decoding than JSON

  ## Examples

      # Encoding
      data = %{"name" => "Alice", "age" => 30, "active" => true}
      {:ok, binary} = Smile.encode(data)

      # Decoding
      {:ok, decoded} = Smile.decode(binary)

      # With options
      Smile.encode(data, shared_names: true, shared_values: true)

  ## Format Specification

  Based on the Smile format specification:
  https://github.com/FasterXML/smile-format-specification

  The Smile format starts with a 4-byte header:
  - Bytes 1-2: `:)` (0x3A 0x29) - The "smiley" signature
  - Byte 3: `\\n` (0x0A) - Line feed
  - Byte 4: Version and flags byte
  """

  alias Smile.Decoder
  alias Smile.Encoder

  @doc """
  Encodes an Elixir term into Smile binary format.

  ## Parameters

    * `term` - The Elixir term to encode (map, list, string, number, boolean, nil)
    * `opts` - Optional keyword list of encoding options

  ## Options

    * `:shared_names` - Enable back references for field names (default: `true`)
    * `:shared_values` - Enable back references for string values (default: `true`)
    * `:raw_binary` - Allow raw binary values (default: `false`)

  ## Returns

    * `{:ok, binary}` - Successfully encoded binary data
    * `{:error, reason}` - Encoding failed with reason

  ## Examples

      iex> {:ok, _binary} = Smile.encode(%{"hello" => "world"})
      iex> {:ok, _binary} = Smile.encode([1, 2, 3])
      iex> {:ok, _binary} = Smile.encode("hello")
      iex> {:ok, _binary} = Smile.encode(42)
      iex> {:ok, _binary} = Smile.encode(true)
  """
  @spec encode(term(), keyword()) :: {:ok, binary()} | {:error, term()}
  def encode(term, opts \\ []) do
    Encoder.encode(term, opts)
  end

  @doc """
  Encodes an Elixir term into Smile binary format, raising on error.

  Same as `encode/2` but raises `RuntimeError` if encoding fails.

  ## Examples

      iex> binary = Smile.encode!(%{"hello" => "world"})
      iex> is_binary(binary)
      true
  """
  @spec encode!(term(), keyword()) :: binary()
  def encode!(term, opts \\ []) do
    case encode(term, opts) do
      {:ok, binary} -> binary
      {:error, reason} -> raise "Smile encoding failed: #{inspect(reason)}"
    end
  end

  @doc """
  Decodes Smile binary format into an Elixir term.

  ## Parameters

    * `binary` - The Smile-encoded binary data

  ## Returns

    * `{:ok, term}` - Successfully decoded term
    * `{:error, reason}` - Decoding failed with reason

  ## Examples

      iex> {:ok, binary} = Smile.encode(%{"hello" => "world"})
      iex> {:ok, decoded} = Smile.decode(binary)
      iex> decoded
      %{"hello" => "world"}

      iex> Smile.decode(<<1, 2, 3>>)
      {:error, :invalid_header}
  """
  @spec decode(binary()) :: {:ok, term()} | {:error, term()}
  def decode(binary) when is_binary(binary) do
    Decoder.decode(binary)
  end

  @doc """
  Decodes Smile binary format into an Elixir term, raising on error.

  Same as `decode/1` but raises `RuntimeError` if decoding fails.

  ## Examples

      iex> {:ok, binary} = Smile.encode(%{"test" => true})
      iex> decoded = Smile.decode!(binary)
      iex> decoded
      %{"test" => true}
  """
  @spec decode!(binary()) :: term()
  def decode!(binary) when is_binary(binary) do
    case decode(binary) do
      {:ok, term} -> term
      {:error, reason} -> raise "Smile decoding failed: #{inspect(reason)}"
    end
  end
end
