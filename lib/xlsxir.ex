defmodule Xlsxir do
  alias Xlsxir.{XlsxFile}

  use Application

  def start(_type, _args) do
    children = [
      %{id: Xlsxir.StateManager, start: {Xlsxir.StateManager, :start_link, []}, type: :worker}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  @moduledoc """
  Extracts and parses data from a `.xlsx` file to an Erlang Term Storage (ETS) process and provides various functions for accessing the data.
  """

  @doc """
  **Deprecated**
  Extracts worksheet data contained in the specified `.xlsx` file to an ETS process. Successful extraction
  returns `{:ok, tid}` with the timer argument set to false and returns a tuple of `{:ok, tid, time}` where time is a list containing time elapsed during the extraction process
  (i.e. `[hour, minute, second, microsecond]`) when the timer argument is set to true and tid - is the ETS table id

  Cells containing formulas in the worksheet are extracted as either a `string`, `integer` or `float` depending on the resulting value of the cell.
  Cells containing an ISO 8601 date format are extracted and converted to Erlang `:calendar.date()` format (i.e. `{year, month, day}`).

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `timer` - boolean flag that tracks extraction process time and returns it when set to `true`. Default value is `false`.

  ## Options
  - `:max_rows` - the number of rows to fetch from within the worksheet
  - `:extract_to` - Specify how the `.xlsx` content (i.e. sharedStrings.xml,
     style.xml and worksheets xml files) will be be extracted before being parsed.
    `:memory` will extract files to memory, and `:file` to files in the file system
  - `:extract_base_dir` - when extracting to file, files will be extracted
     in a sub directory in the `:extract_base_dir` directory. Defaults to
     `Application.get_env(:xlsxir, :extract_base_dir)` or "temp"

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
        iex> Enum.member?(:ets.all, tid)
        true
        iex> Xlsxir.close(tid)
        :ok

        iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0, false, [extract_to: :file])
        iex> Enum.member?(:ets.all, tid)
        true
        iex> Xlsxir.close(tid)
        :ok

        iex> {:ok, tid, _timer} = Xlsxir.extract("./test/test_data/test.xlsx", 0, true)
        iex> Enum.member?(:ets.all, tid)
        true
        iex> Xlsxir.close(tid)
        :ok

  ## Test parallel parsing
        iex> task1 = Task.async(fn -> Xlsxir.extract("./test/test_data/test.xlsx", 0) end)
        iex> task2 = Task.async(fn -> Xlsxir.extract("./test/test_data/test.xlsx", 0) end)
        iex> {:ok, tid1} = Task.await(task1)
        iex> {:ok, tid2} = Task.await(task2)
        iex> Xlsxir.get_list(tid1)
        [["string one", "string two", 10, 20, {2016, 1, 1}]]
        iex> Xlsxir.get_list(tid2)
        [["string one", "string two", 10, 20, {2016, 1, 1}]]
        iex> Xlsxir.close(tid1)
        :ok
        iex> Xlsxir.close(tid2)
        :ok

  ## Example (errors)

        iex> Xlsxir.extract("./test/test_data/test.invalidfile", 0)
        {:error, "Invalid file type (expected xlsx)."}

        iex> Xlsxir.extract("./test/test_data/test.xlsx", 100)
        {:error, "Invalid worksheet index."}
  """
  def extract(path, index, timer \\ false, options \\ []) do
    xlsx_file = XlsxFile.initialize(path, options)
    result = XlsxFile.parse_to_ets(xlsx_file, index, timer)
    XlsxFile.clean(xlsx_file)
    result
  end

  @doc """
  Stream worksheet rows contained in the specified `.xlsx` file.

  Cells containing formulas in the worksheet are extracted as either a `string`, `integer` or `float` depending on the resulting value of the cell.
  Cells containing an ISO 8601 date format are extracted and converted to Erlang `:calendar.date()` format (i.e. `{year, month, day}`).

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)

  ## Options
  - `:extract_to` - Specify how the `.xlsx` content (i.e. sharedStrings.xml,
     style.xml and worksheets xml files) will be be extracted before being parsed.
    `:memory` will extract files to memory, and `:file` to files in the file system
  - `:extract_base_dir` - when extracting to file, files will be extracted
     in a sub directory in the `:extract_base_dir` directory. Defaults to
     `Application.get_env(:xlsxir, :extract_base_dir)` or "temp"

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> Xlsxir.stream_list("./test/test_data/test.xlsx", 1) |> Enum.take(1)
        [[1, 2]]
        iex> Xlsxir.stream_list("./test/test_data/test.xlsx", 1) |> Enum.take(3)
        [[1, 2], [3, 4]]
  """
  def stream_list(path, index, options \\ []) do
    path
    |> stream(index, options)
    |> Stream.map(&row_data_to_list/1)
  end

  defp stream(path, index, options) do
    path
    |> XlsxFile.stream(index, Keyword.merge([extract_to: :file], options))
  end

  defp row_data_to_list(row_data) do
    # from: [["A1", 1], ["B1", nil], ["C1", 2]]
    # to: [1, nil, 2]
    Enum.map(row_data, fn [_ref, val] -> val end)
  end

  @doc """
  Extracts the first n number of rows from the specified worksheet contained in the specified `.xlsx` file to an ETS process.
  Successful extraction returns `{:ok, tid}` where tid - is ETS table id.

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `rows` - the number of rows to fetch from within the specified worksheet

  ## Options
  - `:extract_to` - Specify how the `.xlsx` content (i.e. sharedStrings.xml,
     style.xml and worksheets xml files) will be be extracted before being parsed.
    `:memory` will extract files to memory, and `:file` to files in the file system
  - `:extract_base_dir` - when extracting to file, files will be extracted
     in a sub directory in the `:extract_base_dir` directory. Defaults to
     `Application.get_env(:xlsxir, :extract_base_dir)` or "temp"

  ## Example
  Peek at the first 10 rows of the 9th worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> {:ok, tid} = Xlsxir.peek("./test/test_data/test.xlsx", 8, 10)
        iex> Enum.member?(:ets.all, tid)
        true
        iex> Xlsxir.close(tid)
        :ok
  """
  def peek(path, index, rows, options \\ []) do
    extract(path, index, false, Keyword.merge(options, max_rows: rows))
  end

  @doc """
  Extracts worksheet data contained in the specified `.xlsx` file to an ETS process. Successful extraction
  returns `{:ok, table_id}` with the timer argument set to false and returns a tuple of `{:ok, table_id, time}` where `time` is a list containing time elapsed during the extraction process
  (i.e. `[hour, minute, second, microsecond]`) when the timer argument is set to true. The `table_id` is used to access data for that particular ETS process with the various access functions of the
  `Xlsxir` module.

  Cells containing formulas in the worksheet are extracted as either a `string`, `integer` or `float` depending on the resulting value of the cell.
  Cells containing an ISO 8601 date format are extracted and converted to Erlang `:calendar.date()` format (i.e. `{year, month, day}`).

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `timer` - boolean flag that tracts extraction process time and returns it when set to `true`. Defalut value is `false`.

  ## Options
  - `:max_rows` - the number of rows to fetch from within the worksheets
  - `:extract_to` - Specify how the `.xlsx` content (i.e. sharedStrings.xml,
     style.xml and worksheets xml files) will be be extracted before being parsed.
    `:memory` will extract files to memory, and `:file` to files in the file system
  - `:extract_base_dir` - when extracting to file, files will be extracted
     in a sub directory in the `:extract_base_dir` directory. Defaults to
     `Application.get_env(:xlsxir, :extract_base_dir)` or "temp"

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
        iex> Enum.member?(:ets.all, tid)
        true
        iex> Xlsxir.close(tid)
        :ok

  ## Example
  Extract all worksheets in an example file named `test.xlsx` located in `./test/test_data`:

        iex> results = Xlsxir.multi_extract("./test/test_data/test.xlsx")
        iex> alive_ids = Enum.map(results, fn {:ok, tid} -> Enum.member?(:ets.all, tid) end)
        iex> Enum.all?(alive_ids)
        true
        iex> Enum.map(results, fn {:ok, tid} -> Xlsxir.close(tid) end) |> Enum.all?(fn result -> result == :ok end)
        true

  ## Example
  Extract all worksheets in an example file named `test.xlsx` located in `./test/test_data` with timer:

        iex> results = Xlsxir.multi_extract("./test/test_data/test.xlsx", nil, true)
        iex> alive_ids = Enum.map(results, fn {:ok, tid, _timer} -> Enum.member?(:ets.all, tid) end)
        iex> Enum.all?(alive_ids)
        true
        iex> Enum.map(results, fn {:ok, tid, _timer} -> Xlsxir.close(tid) end) |> Enum.all?(fn result -> result == :ok end)
        true

  ## Example (errors)

        iex> Xlsxir.multi_extract("./test/test_data/test.invalidfile", 0)
        {:error, "Invalid file type (expected xlsx)."}

        iex> Xlsxir.multi_extract("./test/test_data/test.xlsx", 100)
        {:error, "Invalid worksheet index."}
  """
  def multi_extract(path, index \\ nil, timer \\ false, _excel \\ nil, options \\ [])

  def multi_extract(path, nil, timer, _excel, options) do
    case XlsxFile.initialize(path, options) do
      {:error, msg} ->
        {:error, msg}

      xlsx_file ->
        results = XlsxFile.parse_all_to_ets(xlsx_file, timer)
        XlsxFile.clean(xlsx_file)
        results
    end
  end

  def multi_extract(path, index, timer, _excel, options) when is_integer(index) do
    extract(path, index, timer, options)
  end

  @doc """
  Accesses ETS process and returns data formatted as a list of row value lists.

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_list(tid)
          [["string one", "string two", 10, 20, {2016, 1, 1}]]
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 2)
          iex> Xlsxir.get_list(tid) |> List.first |> Enum.count
          16384

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_list(tid)
          [["string one", "string two", 10, 20, {2016, 1, 1}]]
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_list(tid) do
    :ets.match(tid, {:"$1", :"$2"})
    |> Enum.sort()
    |> Enum.map(fn [_num, row] ->
      Enum.map(row, fn [_ref, val] -> val end)
    end)
  end

  @doc """
  Accesses ETS process and returns data formatted as a map of cell references and values.

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_map(tid)
          %{ "A1" => "string one", "B1" => "string two", "C1" => 10, "D1" => 20, "E1" => {2016,1,1}}
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_map(tid)
          %{ "A1" => "string one", "B1" => "string two", "C1" => 10, "D1" => 20, "E1" => {2016,1,1}}
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_map(tid) do
    :ets.match(tid, {:"$1", :"$2"})
    |> Enum.reduce(%{}, fn [_num, row], acc ->
      row
      |> Enum.reduce(%{}, fn [ref, val], acc2 -> Map.put(acc2, ref, val) end)
      |> Enum.into(acc)
    end)
  end

  @doc """
  Accesses ETS process and returns an indexed map which functions like a multi-dimensional array in other languages.

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> mda = Xlsxir.get_mda(tid)
          %{0 => %{0 => "string one", 1 => "string two", 2 => 10, 3 => 20, 4 => {2016,1,1}}}
          iex> mda[0][0]
          "string one"
          iex> mda[0][2]
          10
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> mda = Xlsxir.get_mda(tid)
          %{0 => %{0 => "string one", 1 => "string two", 2 => 10, 3 => 20, 4 => {2016,1,1}}}
          iex> mda[0][0]
          "string one"
          iex> mda[0][2]
          10
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_mda(tid) do
    tid |> :ets.match({:"$1", :"$2"}) |> convert_to_indexed_map(%{})
  end

  defp convert_to_indexed_map([], map), do: map

  defp convert_to_indexed_map([h | t], map) do
    row_index =
      h
      |> Enum.at(0)
      |> Kernel.-(1)

    add_row =
      h
      |> Enum.at(1)
      |> Enum.reduce({%{}, 0}, fn cell, {acc, index} ->
        {Map.put(acc, index, Enum.at(cell, 1)), index + 1}
      end)
      |> elem(0)

    updated_map = Map.put(map, row_index, add_row)
    convert_to_indexed_map(t, updated_map)
  end

  @doc """
  Accesses ETS process and returns value of specified cell.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed
  - `cell_ref` - Reference name of cell to be returned in `string` format (i.e. `"A1"`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_cell(tid, "A1")
          "string one"
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_cell(tid, "A1")
          "string one"
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_cell(table_id, cell_ref), do: do_get_cell(cell_ref, table_id)

  defp do_get_cell(cell_ref, table_id) do
    [[row_num]] = ~r/\d+/ |> Regex.scan(cell_ref)
    row_num = row_num |> String.to_integer()

    with [[row]] <- :ets.match(table_id, {row_num, :"$1"}),
         [^cell_ref, value] <- Enum.find(row, fn [ref, _val] -> ref == cell_ref end) do
      value
    else
      _ -> nil
    end
  end

  @doc """
  Accesses ETS process and returns values of specified row in a `list`.

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed
  - `row` - Reference name of row to be returned in `integer` format (i.e. `1`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_row(tid, 1)
          ["string one", "string two", 10, 20, {2016, 1, 1}]
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_row(tid, 1)
          ["string one", "string two", 10, 20, {2016, 1, 1}]
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_row(tid, row) do
    case :ets.match(tid, {row, :"$1"}) do
      [[row]] -> row |> Enum.map(fn [_ref, val] -> val end)
      [] -> []
    end
  end

  @doc """
  Accesses `tid` ETS process and returns values of specified column in a `list`.

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed
  - `col` - Reference name of column to be returned in `string` format (i.e. `"A"`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_col(tid, "A")
          ["string one"]
          iex> Xlsxir.close(tid)
          :ok

          iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> Xlsxir.get_col(tid, "A")
          ["string one"]
          iex> Xlsxir.close(tid)
          :ok
  """
  def get_col(tid, col), do: do_get_col(col, tid)

  defp do_get_col(col, tid) do
    tid
    |> :ets.match({:"$1", :"$2"})
    |> Enum.sort()
    |> Enum.map(fn [_num, row] ->
      row
      |> Enum.filter(fn [ref, _val] -> Regex.scan(~r/[A-Z]+/i, ref) == [[col]] end)
      |> Enum.map(fn [_ref, val] -> val end)
    end)
    |> List.flatten()
  end

  @doc """
  See `get_multi_info/2` documentation.
  """
  def get_info(table_id, num_type \\ :all) do
    get_multi_info(table_id, num_type)
  end

  @doc """
  Returns count data based on `num_type` specified:
  - `:rows` - Returns number of rows contained in worksheet
  - `:cols` - Returns number of columns contained in worksheet
  - `:cells` - Returns number of cells contained in worksheet
  - `:name` - Returns worksheet name
  - `:all` - Returns a keyword list containing all of the above

  ## Parameters
  - `tid` - table identifier of ETS process to be accessed
  - `num_type` - type of count data to be returned (see above), defaults to `:all`
  """
  def get_multi_info(tid, num_type \\ :all) do
    case num_type do
      :rows ->
        row_num(tid)

      :cols ->
        col_num(tid)

      :cells ->
        cell_num(tid)

      :name ->
        worksheet_name(tid)

      _ ->
        [
          rows: row_num(tid),
          cols: col_num(tid),
          cells: cell_num(tid),
          name: worksheet_name(tid)
        ]
    end
  end

  defp row_num(tid) do
    # do not count :info key
    :ets.info(tid, :size) - 1
  end

  defp col_num(tid) do
    :ets.match(tid, {:"$1", :"$2"})
    |> Enum.map(fn [_num, row] -> Enum.count(row) end)
    |> Enum.max()
  end

  defp cell_num(tid) do
    :ets.match(tid, {:"$1", :"$2"})
    |> Enum.reduce(0, fn [_num, row], acc -> acc + Enum.count(row) end)
  end

  defp worksheet_name(tid) do
    List.foldl(:ets.lookup(tid, :info), nil, fn value, _ ->
      case value do
        {:info, :worksheet_name, name} -> name
        _ -> nil
      end
    end)
  end

  @doc """
  Fill every row with `nil` cells at the end.
  Cells quantity determined by the max length of all rows.

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:
      iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 10)
      iex> Xlsxir.set_empty_cells_to_fill_rows(tid)
      {:ok, tid}
      iex> Xlsxir.get_row(tid, 1)
      [1, nil, 1, nil, 1, nil, nil, 1, nil, nil]
      iex> Xlsxir.get_col(tid, "J")
      [nil, nil, 1, nil]
  """
  def set_empty_cells_to_fill_rows(tid) do
    Xlsxir.XlsxFile.set_empty_cells_to_fill_rows(tid)
  end

  @doc """
  Deletes ETS process `tid` and returns `:ok` if successful.

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

      iex> {:ok, tid} = Xlsxir.extract("./test/test_data/test.xlsx", 0)
      iex> Xlsxir.close(tid)
      :ok

      iex> {:ok, tid} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
      iex> Xlsxir.close(tid)
      :ok
  """
  def close(tid) do
    if Enum.member?(:ets.all(), tid) do
      if :ets.delete(tid), do: :ok, else: :error
    else
      :ok
    end
  end
end
