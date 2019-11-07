defmodule Xlsxir.Unzip do
  alias Xlsxir.XmlFile

  @filetype_error "Invalid file type (expected xlsx)."
  @xml_not_found_error "Invalid File. Required XML files not found."

  @doc """
  Extracts requested list of files from a `.zip` file to memory or file system
  and returns a list of the extracted file paths.

  ## Parameters

  - `file_list` - list containing file paths to be extracted in `char_list` format
  - `path` - file path of a `.xlsx` file type in `string` format
  - `to` - `:memory` or `{:file, "destination/path"}` option

  ## Example
  An example file named `test.zip` located in './test_data/test' containing a single file named `test.txt`:

      iex> path = "./test/test_data/test.zip"
      iex> file_list = ['test.txt']
      iex> Xlsxir.Unzip.extract_xml(file_list, path, :memory)
      {:ok, [%Xlsxir.XmlFile{content: "test_successful", name: "test.txt", path: nil}]}
      iex> Xlsxir.Unzip.extract_xml(file_list, path, {:file, "temp/"})
      {:ok, [%Xlsxir.XmlFile{content: nil, name: "test.txt", path: "temp/test.txt"}]}
      iex> with {:ok, _} <- File.rm_rf("temp"), do: :ok
      :ok
  """
  def extract_xml(file_list, path, to) do
    path
    |> to_charlist
    |> extract_from_zip(file_list, to)
    |> case do
      {:error, :einval} -> {:error, @filetype_error}
      {:error, reason} -> {:error, reason}
      {:ok, []} -> {:error, @xml_not_found_error}
      {:ok, files_list} -> {:ok, build_xml_files(files_list)}
    end
  end

  defp extract_from_zip(path, file_list, :memory),
    do: :zip.extract(path, [{:file_list, file_list}, :memory])

  defp extract_from_zip(path, file_list, {:file, dest_path}),
    do: :zip.extract(path, [{:file_list, file_list}, {:cwd, dest_path}])

  defp build_xml_files(files_list) do
    files_list
    |> Enum.map(&build_xml_file/1)
  end

  # When extracting to memory
  defp build_xml_file({name, content}) do
    %XmlFile{name: Path.basename(name), content: content}
  end

  # When extracting to temp file
  defp build_xml_file(file_path) do
    %XmlFile{name: Path.basename(file_path), path: to_string(file_path)}
  end
end
