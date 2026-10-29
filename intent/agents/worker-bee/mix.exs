defmodule WorkerBee.MixProject do
  use Mix.Project

  def project do
    [
      app: :worker_bee,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: ["lib", "validation"],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.11"}
    ]
  end
end
