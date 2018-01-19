defmodule Xlsxir.Mixfile do
  use Mix.Project

  def project do
    [
     app: :xlsxir,
     version: "1.6.3",
     name: "Xlsxir",
     source_url: "https://github.com/jsonkenl/xlsxir",
     elixir: "~> 1.6",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps(),
     docs: [main: "overview", extras: ["CHANGELOG.md", "NUMBER_STYLES.md", "OVERVIEW.md"]]
    ]
  end

  def application do
    [
      mod: {Xlsxir, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: :dev},
      {:earmark, github: "pragdave/earmark", override: true, only: :dev},
      {:erlsom, "~> 1.4"}
    ]
  end

  defp description do
    """
    Xlsx file parser (Excel, LibreOffice, etc.)
    """
  end

  defp package do
    [
      maintainers: ["Jason Kennell"],
      licenses: ["MIT License"],
      links: %{
                "Github" => "https://github.com/jsonkenl/xlsxir",
                "Change Log" => "https://hexdocs.pm/xlsxir/changelog.html"
               }
    ]
  end

end
