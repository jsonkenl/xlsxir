defmodule Xlsxir.SaxParser do
  @moduledoc """
  Provides SAX (Simple API for XML) parsing functionality of the `.xlsx` file via the [Erlsom](https://github.com/willemdj/erlsom) Erlang library. SAX (Simple API for XML) is an event-driven
  parsing algorithm for parsing large XML files in chunks, preventing the need to load the entire DOM into memory. Current chunk size is set to 10,000.
  """

  alias Xlsxir.{ParseString, ParseStyle, ParseWorksheet, SharedString, Style, TableId, Worksheet, SaxError}
  require Logger

  @chunk 10000

  @doc """
  Parses `xl/worksheets/sheet\#{n}.xml` at index `n`, `xl/styles.xml` and `xl/sharedStrings.xml` using SAX parsing. An Erlang Term Storage (ETS) process is started to hold the state of data
  parsed. Name of ETS process modules that hold data for the aforementioned XML files are `Worksheet`, `Style` and `SharedString` respectively. The style and sharedstring XML files (if they
  exist) must be parsed first in order for the worksheet parser to sucessfully complete.

  ## Parameters

  - `path` - path of XML file to be parsed in `string` format
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
    data. Keep in mind that the worksheet data is stored in the ETS process as a list of row lists, so the `Xlsxir.Worksheet.get_at/1` function will return a full row of values.

          iex> Xlsxir.SaxParser.parse(File.read!("./test/test_data/test/xl/styles.xml"), :style)
          :ok
          iex> Xlsxir.Style.get_at(0)
          nil
          iex> Xlsxir.SaxParser.parse(File.read!("./test/test_data/test/xl/sharedStrings.xml"), :string)
          :ok
          iex> Xlsxir.SharedString.get_at(0)
          "string one"
          iex> Xlsxir.SaxParser.parse(File.read!("./test/test_data/test/xl/worksheets/sheet1.xml"), :worksheet)
          :ok
          iex> Xlsxir.Worksheet.get_at(1)
          [["A1", "string one"], ["B1", "string two"], ["C1", 10], ["D1", 20], ["E1", {2016, 1, 1}]]
          iex> Xlsxir.Worksheet.delete
          true
  """
  def parse(content, type, max_rows \\ nil) do
    case type do
      :worksheet -> Worksheet.new
      :multi     -> Worksheet.new_multi
      :style     -> Style.new
      :string    -> SharedString.new
    end

    {:ok, pid} = File.open(content, [:binary, :ram])

    index   = 0
    c_state = {pid, index, @chunk}

    try do
      Agent.start(fn -> max_rows end, name: MaxRows)
      :erlsom.parse_sax("",
        nil,
        case type do
          :worksheet -> &ParseWorksheet.sax_event_handler/2
          :multi     -> &ParseWorksheet.sax_event_handler/2
          :style     -> &ParseStyle.sax_event_handler/2
          :string    -> &ParseString.sax_event_handler/2
          _          -> raise "Invalid file type for sax_event_handler/2"
        end,
        [{:continuation_function, &continue_file/2, c_state}])
    rescue SaxError -> nil
      after
        Agent.stop(MaxRows)
        File.close(pid)
    end

    if type == :multi do
      table_id = TableId.get
      TableId.delete
      {:ok, table_id}
    else
      :ok
    end
  end

  defp continue_file(tail, {pid, offset, chunk}) do
    case :file.pread(pid, offset, chunk) do
      {:ok, data} -> {<<tail :: binary, data :: binary>>, {pid, offset + chunk, chunk}}
      :eof        -> {tail, {pid, offset, chunk}}
    end
  end

end

