defmodule Exdn.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exdn,
      version: "2.2.0",
      description: """
      a two-way translator between Elixir data structures and strings of data
      following the edn specification.
      """,
      package: package(),
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application() do
    [extra_applications: [:logger, :calendar, :erldn]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps() do
    [
      {:erldn, "~> 1.0.6"},
      {:calendar, "~> 1.0.0"},
      {:credo, "~> 1.4.1", only: [:dev, :test, :ci], runtime: false},
      {:ex_doc, "~> 0.23.0", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 0.3", only: :dev}
    ]
  end

  defp package() do
    [
      maintainers: ["Paul Blair"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/psfblair/exdn"}
    ]
  end
end
