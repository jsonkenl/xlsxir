defmodule Xlsxir.XmlFile do
  @moduledoc """
  Struct that represents an XML file extracted from an `xlsx` file,
  either in memory (in the `content` field) or on the filesystem
  (located in the `path` field)
  """

  defstruct name: nil, path: nil, content: nil

  @doc """
  Open an XmlFile

  ## Parameters
  - `xml_file` - xml file to open
  """
  def open(%__MODULE__{} = xml_file) do
    case Map.get(xml_file, :content, nil) do
      nil -> File.open(xml_file.path, [:binary])
      content -> File.open(content, [:binary, :ram])
    end
  end
end
