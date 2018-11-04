# Smile


An API for serializing and de-serializing Elixir terms using the Smile data interchange format.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `smile` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:smile, "~> 0.1.0"}
  ]
end
```

## A Quick Example

```elixir
iex>  o = %{"a": 1, "b": [2, 3, 4], "c": {"d": {"e": 4.20}}}
iex> {:ok, encoded} = Smile.encode(o)
iex> IO.puts encoded
":)\n\x03\xfa\x80a\xc2\x80c\xfa\x80d\xfa\x80e(fL\x19\x04\x04\xfb\xfb\x80b\xf8\xc4\xc6\xc8\xf9\xfb"
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/smile](https://hexdocs.pm/smile).

