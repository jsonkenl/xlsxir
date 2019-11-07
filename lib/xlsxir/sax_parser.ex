defmodule Xlsxir.SaxParser do
  @moduledoc """
  Provides SAX (Simple API for XML) parsing functionality of the `.xlsx` file via the [Erlsom](https://github.com/willemdj/erlsom) Erlang library. SAX (Simple API for XML) is an event-driven
  parsing algorithm for parsing large XML files in chunks, preventing the need to load the entire DOM into memory. Current chunk size is set to 10,000.
  """

  alias Xlsxir.{
    ParseString,
    ParseStyle,
    ParseWorkbook,
    ParseWorksheet,
    ParseRelationships,
    StreamWorksheet,
    SaxError,
    XmlFile
  }

  require Logger

  @chunk 10_000

  @doc """
  Parses `XmlFile` (`xl/worksheets/sheet\#{n}.xml` at index `n`, `xl/styles.xml`, `xl/workbook.xml` or `xl/sharedStrings.xml`) using SAX parsing. An Erlang Term Storage (ETS) process is started to hold the state of data
  parsed. The style and sharedstring XML files (if they exist) must be parsed first in order for the worksheet parser to sucessfully complete.

  ## Parameters

  - `content` - XML string to parse
  - `type` - file type identifier (:worksheet, :style or :string) of XML file to be parsed
  - `max_rows` - the maximum number of rows in this worksheet that should be parsed

  ## Example
    An example file named `test.xlsx` located in `./test/test_data` containing the following in worksheet at index `0`:
    - cell 'A1' -> "string one"
    - cell 'B1' -> "string two"
    - cell 'C1' -> integer of 10
    - cell 'D1' -> formula of `=4*5`
    - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370
    The `.xlsx` file contents have been extracted to `./test/test_data/test`. For purposes of this example, we utilize the `get_at/1` function of each ETS process module to pull a sample of the parsed
    data. Keep in mind that the worksheet data is stored in the ETS process as a list of row lists, so the `Xlsxir..get_row/2` function will return a full row of values.

          iex> {:ok, %Xlsxir.ParseStyle{tid: tid1}, _} = Xlsxir.SaxParser.parse(%Xlsxir.XmlFile{content: File.read!("./test/test_data/test/xl/styles.xml")}, :style)
          iex> :ets.lookup(tid1, 0)
          [{0, nil}]
          iex> {:ok, %Xlsxir.ParseString{tid: tid2}, _} = Xlsxir.SaxParser.parse(%Xlsxir.XmlFile{content: File.read!("./test/test_data/test/xl/sharedStrings.xml")}, :string)
          iex> :ets.lookup(tid2, 0)
          [{0, "string one"}]
          iex> {:ok, %Xlsxir.ParseWorkbook{tid: tid3}, _} = Xlsxir.SaxParser.parse(%Xlsxir.XmlFile{content: File.read!("./test/test_data/test/xl/workbook.xml")}, :workbook)
          iex> :ets.lookup(tid3, "rId1")
          [{"rId1", "Sheet1", 0}]
          iex> {:ok, %Xlsxir.ParseWorksheet{tid: tid4}, _} = Xlsxir.SaxParser.parse(%Xlsxir.XmlFile{name: "sheet1.xml", content: File.read!("./test/test_data/test/xl/worksheets/sheet1.xml")}, :worksheet, %Xlsxir.XlsxFile{shared_strings: tid2, styles: tid1, workbook: tid3})
          iex> :ets.lookup(tid4, 1)
          [{1, [["A1", "string one"], ["B1", "string two"], ["C1", 10], ["D1", 20], ["E1", {2016, 1, 1}]]}]
  """
  def parse(%XmlFile{} = xml_file, type, xslx_file \\ nil, initial_state \\ nil) do
    {:ok, file_pid} = XmlFile.open(xml_file)

    index = 0
    c_state = {file_pid, index, @chunk}

    try do
      :erlsom.parse_sax(
        "",
        initial_state,
        case type do
          :worksheet -> &ParseWorksheet.sax_event_handler(&1, &2, xslx_file)
          :stream_worksheet -> &StreamWorksheet.sax_event_handler(&1, &2, xslx_file)
          :style -> &ParseStyle.sax_event_handler(&1, &2)
          :workbook -> &ParseWorkbook.sax_event_handler(&1, &2)
          :workbook_rels -> &ParseRelationships.sax_event_handler(&1, &2)
          :string -> &ParseString.sax_event_handler(&1, &2)
          _ -> raise "Invalid file type for sax_event_handler/2"
        end,
        [{:continuation_function, &continue_file/2, c_state}]
      )
    rescue
      e in SaxError ->
        {:ok, e.state, []}
    after
      File.close(file_pid)
    end
  end

  defp continue_file(tail, {pid, offset, chunk}) do
    case :file.pread(pid, offset, chunk) do
      {:ok, data} -> {<<tail::binary, data::binary>>, {pid, offset + chunk, chunk}}
      :eof -> {tail, {pid, offset, chunk}}
    end
  end
end
