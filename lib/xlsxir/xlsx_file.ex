defmodule Xlsxir.XlsxFile do
  @moduledoc """
  Struct and helper functions to extract and process `.xslx` files

  ## Example

    iex> xlsx_file = Xlsxir.XlsxFile.initialize("./test/test_data/test.xlsx")
    iex> {:ok, _tid} = Xlsxir.XlsxFile.parse_to_ets(xlsx_file, 0)
    iex> Xlsxir.XlsxFile.clean(xlsx_file)
    :ok
  """

  alias Xlsxir.Unzip
  alias Xlsxir.XmlFile
  alias Xlsxir.SaxParser

  # list of worksheet %XmlFile{}
  defstruct worksheet_xml_files: [],
            # shared strings %XmlFile{}
            shared_strings_xml_file: nil,
            # styles %XmlFile{}
            styles_xml_file: nil,
            # workbook %XmlFile{}
            workbook_xml_file: nil,
            # ets table id
            styles: nil,
            # ets table id
            workbook: nil,
            # ets table id
            shared_strings: nil,
            # maximum rows to process during extraction to ETS
            max_rows: nil,
            extract_to: nil,
            extract_dir: nil,
            options: []

  @default_options extract_to: :memory,
                   extract_base_dir: nil

  @doc """
  Extract and prepare `.xlsx` file content.

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format

  ## Options
  - `:max_rows` - the number of rows to fetch from within the worksheet
  - `:extract_to` - Specify how the `.xlsx` content (i.e. sharedStrings.xml,
     style.xml and worksheets xml files) will be be extracted before being parsed.
    `:memory` will extract files to memory, and `:file` to files in the file system
  - `:extract_base_dir` - when extracting to file, files will be extracted
     in a sub directory in the `:extract_base_dir` directory. Defaults to
     `Application.get_env(:xlsxir, :extract_base_dir)` or "temp"
  """
  def initialize(xlsx_filepath, options \\ []) do
    options = Keyword.merge(@default_options, options)
    max_rows = Keyword.get(options, :max_rows)
    extract_to = Keyword.get(options, :extract_to)
    extract_dir = build_extract_dir(options)

    %__MODULE__{max_rows: max_rows, extract_to: extract_to, extract_dir: extract_dir}
    # Could be optimized to only unzip commons and requested worksheet
    |> extract_all_xml_files(xlsx_filepath)
    |> parse_shared_strings_to_ets
    |> parse_styles_to_ets
    |> parse_workbook_to_ets
  end

  @doc """
  Parse a worksheet of the XlsxFile and store its content in a ETS table.
  returns `{:ok, table_id}` when `timer` is `false`
  and `{:ok, table_id, time}` when `timer` is `true`
  """
  def parse_to_ets(xlsx_file, worksheet_index_or_file, timer \\ false)
  def parse_to_ets({:error, _} = error, _worksheet_index_or_file, _timer), do: error

  def parse_to_ets(%__MODULE__{} = xlsx_file, worksheet_index, timer)
      when is_integer(worksheet_index) do
    with {:ok, worksheet_xml_file} <- get_worksheet(xlsx_file, worksheet_index) do
      parse_to_ets(xlsx_file, worksheet_xml_file, timer)
    end
  end

  def parse_to_ets(%__MODULE__{} = xlsx_file, %XmlFile{} = worksheet_xml_file, true) do
    start_timestamp = :erlang.timestamp()
    {:ok, tid} = parse_to_ets(xlsx_file, worksheet_xml_file, false)
    end_timestamp = :erlang.timestamp()
    {:ok, tid, duration(start_timestamp, end_timestamp)}
  end

  def parse_to_ets(%__MODULE__{} = xlsx_file, %XmlFile{} = worksheet_xml_file, false) do
    {:ok, %Xlsxir.ParseWorksheet{tid: tid}, _} =
      SaxParser.parse(worksheet_xml_file, :worksheet, xlsx_file)

    {:ok, tid}
  end

  @doc """
  Fill every row with `nil` cells at the end.
  Cells quantity determined by the max length of all rows.
  """
  def set_empty_cells_to_fill_rows(tid) do
    max_len =
      :ets.match(tid, {:"$1", :"$2"})
      |> Enum.map(fn [_num, row] -> Enum.count(row) end)
      |> Enum.max()

    end_column = Xlsxir.ParseWorksheet.column_from_index(max_len + 1, "")

    first_key = :ets.first(tid)
    fill_empty_cells_at_end(tid, end_column, first_key)
  end

  defp fill_empty_cells_at_end(tid, _, :"$end_of_table"), do: {:ok, tid}

  defp fill_empty_cells_at_end(tid, end_column, index) when is_integer(index) do
    build_and_replace(tid, end_column, index)
    nex_index = :ets.next(tid, index)
    fill_empty_cells_at_end(tid, end_column, nex_index)
  end

  defp fill_empty_cells_at_end(tid, end_column, index) do
    nex_index = :ets.next(tid, index)
    fill_empty_cells_at_end(tid, end_column, nex_index)
  end

  defp build_and_replace(tid, end_column, index) do
    [{index, cells}] = :ets.lookup(tid, index)
    [last_ref, _] = List.last(cells)
    from = Xlsxir.ParseWorksheet.next_col(last_ref)
    to = end_column <> Integer.to_string(index)

    empty_cells = Xlsxir.ParseWorksheet.fill_empty_cells(from, to, index, [])
    new_cells = cells ++ empty_cells

    true = :ets.insert(tid, {index, new_cells})
  end

  @doc """
  Parse all worksheets of the XlsxFile and store their content in ETS tables.
  returns `[{:ok, worksheet_1_table_id}, ..., {:ok, worksheet_n_table_id}]` when `timer` is `false`
  and `[{:ok, worksheet_1_table_id, time1}, ..., {:ok, worksheet_n_table_id, timen}]` when `timer` is `true`
  """
  def parse_all_to_ets(%__MODULE__{} = xlsx_file, timer \\ false) do
    xlsx_file.worksheet_xml_files
    # Sort worksheets by name (i.e. index)
    |> Enum.sort(&(&1.name <= &2.name))
    |> Enum.map(&parse_to_ets(xlsx_file, &1, timer))
  end

  @doc """
  Clean temp ETS tables and extraction folder
  """
  def clean(%__MODULE__{} = xlsx_file) do
    # delete ETS tables
    if xlsx_file.shared_strings, do: :ets.delete(xlsx_file.shared_strings)
    if xlsx_file.styles, do: :ets.delete(xlsx_file.styles)
    if xlsx_file.workbook, do: :ets.delete(xlsx_file.workbook)

    # Delete extract folder
    if xlsx_file.extract_to == :file do
      File.rm_rf!(xlsx_file.extract_dir)
    end

    :ok
  end

  def clean({:error, _} = error), do: error

  @doc """
  Parse a worksheet of the XlsxFile as a stream
  """
  def stream(xlsx_filepath, worksheet_index, options \\ []) do
    Stream.resource(
      fn -> xlsx_filepath |> initialize(options) |> initialize_stream(worksheet_index) end,
      &stream_next_row/1,
      &clean_stream/1
    )
  end

  ###############################################

  defp build_extract_dir(options) do
    case options[:extract_to] do
      :file ->
        extract_base_dir = build_extract_base_dir(options)
        Path.join(extract_base_dir, Base.url_encode64(:crypto.strong_rand_bytes(10)))

      _ ->
        nil
    end
  end

  defp build_extract_base_dir(options) do
    Keyword.get(options, :extract_base_dir) || Application.get_env(:xlsxir, :extract_base_dir) ||
      "temp"
  end

  defp initialize_stream(%__MODULE__{} = xlsx_file, worksheet_index) do
    {:ok, worksheet_xml_file} = get_worksheet(xlsx_file, worksheet_index)
    sax_parser_pid = spawn(__MODULE__, :parse_worksheet_loop, [worksheet_xml_file, xlsx_file])
    {sax_parser_pid, xlsx_file}
  end

  @doc false
  def parse_worksheet_loop(worksheet_xml_file, xlsx_file) do
    SaxParser.parse(worksheet_xml_file, :stream_worksheet, xlsx_file)
  end

  defp stream_next_row({sax_parser_pid, _xlsx_file} = stream_state) do
    # Ask next row to the xml parser process
    send(sax_parser_pid, {:get_next_row, self()})

    # And wait for a response, ie a next row or end of file
    receive do
      {:next_row, row} ->
        {[row], stream_state}

      {:end} ->
        {:halt, stream_state}
    end
  end

  defp clean_stream({sax_parser_pid, xlsx_file}) do
    # Kill parser loop process and remove common ETS tables
    Process.exit(sax_parser_pid, :kill)
    clean(xlsx_file)
  end

  defp extract_all_xml_files(%__MODULE__{} = xlsx_file, xlsx_filepath) do
    with {:ok, worksheet_indexes} <- Unzip.validate_path_all_indexes(xlsx_filepath),
         xml_paths_list <- zip_paths_list(worksheet_indexes),
         {:ok, xml_files} <-
           Unzip.extract_xml(xml_paths_list, xlsx_filepath, unzip_options(xlsx_file)) do
      %{
        xlsx_file
        | worksheet_xml_files:
            xml_files
            |> Enum.filter(fn %XmlFile{name: name} -> String.starts_with?(name, "sheet") end),
          shared_strings_xml_file:
            xml_files |> Enum.find(fn %XmlFile{name: name} -> name == "sharedStrings.xml" end),
          styles_xml_file:
            xml_files |> Enum.find(fn %XmlFile{name: name} -> name == "styles.xml" end),
          workbook_xml_file:
            xml_files |> Enum.find(fn %XmlFile{name: name} -> name == "workbook.xml" end)
      }
    end
  end

  defp unzip_options(xlsx_file) do
    case xlsx_file.extract_to do
      :file -> {:file, xlsx_file.extract_dir}
      :memory -> :memory
    end
  end

  defp zip_paths_list(worksheet_indexes) do
    worksheet_indexes
    |> Enum.map(fn worksheet_index -> 'xl/worksheets/sheet#{worksheet_index + 1}.xml' end)
    |> Enum.concat(['xl/styles.xml', 'xl/sharedStrings.xml', 'xl/workbook.xml'])
  end

  defp parse_styles_to_ets(%__MODULE__{styles_xml_file: nil} = xlsx_file), do: xlsx_file

  defp parse_styles_to_ets(%__MODULE__{} = xlsx_file) do
    {:ok, %Xlsxir.ParseStyle{tid: tid}, _} = SaxParser.parse(xlsx_file.styles_xml_file, :style)
    %{xlsx_file | styles: tid}
  end

  defp parse_styles_to_ets({:error, _} = error), do: error

  defp parse_workbook_to_ets(%__MODULE__{workbook_xml_file: nil} = xlsx_file),
    do: xlsx_file

  defp parse_workbook_to_ets(%__MODULE__{} = xlsx_file) do
    {:ok, %Xlsxir.ParseWorkbook{tid: tid}, _} =
      SaxParser.parse(xlsx_file.workbook_xml_file, :workbook)

    %{xlsx_file | workbook: tid}
  end

  defp parse_workbook_to_ets({:error, _} = error), do: error

  defp parse_shared_strings_to_ets(%__MODULE__{shared_strings_xml_file: nil} = xlsx_file),
    do: xlsx_file

  defp parse_shared_strings_to_ets(%__MODULE__{} = xlsx_file) do
    {:ok, %Xlsxir.ParseString{tid: tid}, _} =
      SaxParser.parse(xlsx_file.shared_strings_xml_file, :string)

    %{xlsx_file | shared_strings: tid}
  end

  defp parse_shared_strings_to_ets({:error, _} = error), do: error

  defp get_worksheet(%__MODULE__{} = xlsx_file, index) do
    xml_file =
      Enum.find(xlsx_file.worksheet_xml_files, fn xml_file ->
        xml_file.name == "sheet#{index + 1}.xml"
      end)

    case xml_file do
      nil -> {:error, "Invalid worksheet index."}
      %XmlFile{} -> {:ok, xml_file}
    end
  end

  defp duration(start_timestamp, end_timestamp) do
    {_, s, ms} = end_timestamp
    {_, start_s, start_ms} = start_timestamp

    seconds = s |> Kernel.-(start_s)
    microseconds = ms |> Kernel.+(start_ms)

    [add_s, micro] =
      if microseconds > 1_000_000 do
        [1, microseconds - 1_000_000]
      else
        [0, microseconds]
      end

    [h, m, s] = [
      seconds |> Kernel./(3600) |> Float.floor() |> round,
      seconds |> rem(3600) |> Kernel./(60) |> Float.floor() |> round,
      rem(seconds, 60)
    ]

    [h, m, s + add_s, micro]
  end
end
