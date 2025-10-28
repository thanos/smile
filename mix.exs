defmodule SmileEx.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/thanos/smile_ex"

  def project do
    [
      app: :smile_ex,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "SmileEx",
      source_url: @source_url,
      homepage_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Documentation
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},

      # Code quality and testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: :test},

      # Benchmarking and comparison
      {:benchee, "~> 1.5.0", only: :dev, runtime: false},
      {:jason, "~> 1.4", only: [:dev, :test]}
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
      name: "smile_ex",
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
        Constants: [Smile.Constants]
      ]
    ]
  end
end
