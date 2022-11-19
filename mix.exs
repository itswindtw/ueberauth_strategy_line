defmodule Ueberauth.Strategy.Line.MixProject do
  use Mix.Project

  def project do
    [
      app: :ueberauth_strategy_line,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [ignore_modules: [Ueberauth.Strategy.Line.API.Finch]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Ueberauth.Strategy.Line.Application, []}
    ]
  end

  defp deps do
    [
      {:ueberauth, "~> 0.7"},
      {:finch, "~> 0.13.0"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
