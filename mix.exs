defmodule Smile.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thanos/smile"

  def project do
    [
      app: :smile,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Smile",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir encoder and decoder for the Smile binary data interchange format.
    Smile is a binary format based on JSON that provides better performance
    and more compact encoding than text-based JSON.
    """
  end

  defp package do
    [
      name: "smile",
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
      maintainers: ["Thanos Vassilakis"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Specification" => "https://github.com/FasterXML/smile-format-specification",
        "Wikipedia" => "https://en.wikipedia.org/wiki/Smile_%28data_interchange_format%29"
      }
    ]
  end

  defp docs do
    [
      main: "Smile",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [Smile],
        "Encoding & Decoding": [Smile.Encoder, Smile.Decoder],
        "Constants": [Smile.Constants]
      ]
    ]
  end
end
