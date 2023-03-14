defmodule Xlsxir.Mixfile do
  use Mix.Project

  def project do
    [
     app: :xlsxir,
     version: "1.6.4",
     name: "Xlsxir",
     source_url: "https://github.com/jsonkenl/xlsxir",
     elixir: "~> 1.4",
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
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:erlsom, "~> 1.5"}
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
