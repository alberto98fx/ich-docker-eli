defmodule DbQueryAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :db_query_api,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :cowboy, :plug_cowboy],
      mod: {DbQueryAPI.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.5"},
      {:myxql, "~> 0.6.0"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"}
    ]
  end

end
