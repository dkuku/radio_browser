defmodule RadioBrowser.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/kuku/radio_browser"

  def project do
    [
      app: :radio_browser,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),

      # Hex
      description:
        "An Elixir client for the Radio Browser API, providing access to a worldwide radio station directory",
      package: package(),

      # Docs
      name: "RadioBrowser",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RadioBrowser.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dns, "~> 2.0"},
      {:req, "~> 0.5"},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Daniel Kukuła"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Radio Browser API" => "https://api.radio-browser.info/"
      },
      files: ~w(lib .formatter.exs mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
