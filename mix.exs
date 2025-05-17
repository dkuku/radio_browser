defmodule RadioBrowser.MixProject do
  use Mix.Project

  def project do
    [
      app: :radio_browser,
      version: "0.1.0",
      elixir: "~> 1.19-dev",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps()
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
      {:igniter, "~> 0.5", only: [:dev, :test]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
