defmodule Xlsxir do
  alias Xlsxir.{Index, SaxParser, Timer, Unzip, Worksheet}

  @moduledoc """
  Extracts and parses data from a `.xlsx` file to an Erlang Term Storage (ETS) process and provides various functions for accessing the data.
  """

  @doc """
  Extracts worksheet data contained in the specified `.xlsx` file to an ETS process named `:worksheet` which is accessed via the `Xlsxir.Worksheet` module. Successful extraction
  returns `:ok` with the timer argument set to false and returns a tuple of `{:ok, time}` where time is a list containing time elapsed during the extraction process
  (i.e. `[hour, minute, second, microsecond]`) when the timer argument is set to true.

  Cells containing formulas in the worksheet are extracted as either a `string`, `integer` or `float` depending on the resulting value of the cell.
  Cells containing an ISO 8601 date format are extracted and converted to Erlang `:calendar.date()` format (i.e. `{year, month, day}`).

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `timer` - boolean flag that tracks extraction process time and returns it when set to `true`. Defalut value is `false`.

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
        :ok
        iex> Xlsxir.Worksheet.alive?
        true
        iex> Xlsxir.close
        :ok
  """
  def extract(path, index, timer \\ false) do
    if timer, do: Timer.start
    case Unzip.validate_path_and_index(path, index) do
      {:ok, file}      ->
        case extract_xml(file, index) do
          {:ok, file_paths} -> do_extract(file_paths, index, timer)
          {:error, reason}  -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_extract(file_paths, index, timer) do
    Enum.each(file_paths, fn file ->
      case file do
        'temp/xl/sharedStrings.xml' -> SaxParser.parse(to_string(file), :string)
        'temp/xl/styles.xml'        -> SaxParser.parse(to_string(file), :style)
        _                           -> nil
      end
    end)

    SaxParser.parse("temp/xl/worksheets/sheet#{index + 1}.xml", :worksheet)
    Unzip.delete_dir

    if timer, do: {:ok, Timer.stop}, else: :ok
  end

  @doc """
  Extracts the first n number of rows from the specified worksheet contained in the specified `.xlsx` file to an ETS process
  named `:worksheet` which is accessed via the `Xlsxir.Worksheet` module. Successful extraction returns `:ok`

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `rows` - the number of rows to fetch from within the specified worksheet

  ## Example
  Peek at the first 10 rows of the 9th worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> Xlsxir.peek("./test/test_data/test.xlsx", 8, 10)
        :ok
        iex> Xlsxir.Worksheet.alive?
        true
        iex> Xlsxir.close
        :ok
  """
  def peek(path, index, rows) do
    case Unzip.validate_path_and_index(path, index) do
      {:ok, file}      -> 
        case extract_xml(file, index) do
          {:ok, file_paths} -> do_extract(file_paths, index, false, rows)
          {:error, reason}  -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_xml(file, index) do
    Unzip.xml_file_list(index)
    |> Unzip.extract_xml_to_file(file)
  end

  defp do_extract(file_paths, index, timer, max_rows \\ nil) do
    Enum.each(file_paths, fn file ->
      case file do
        'temp/xl/sharedStrings.xml' -> SaxParser.parse(to_string(file), :string)
        'temp/xl/styles.xml'        -> SaxParser.parse(to_string(file), :style)
        _                           -> nil
      end
    end)

    SaxParser.parse("temp/xl/worksheets/sheet#{index + 1}.xml", :worksheet, max_rows)
    Unzip.delete_dir

    if timer, do: {:ok, Timer.stop}, else: :ok
  end

  @doc """
  Extracts worksheet data contained in the specified `.xlsx` file to an ETS process with a table identifier of `table_id` which is accessed via the `Xlsxir.Worksheet` module. Successful extraction
  returns `{:ok, table_id}` with the timer argument set to false and returns a tuple of `{:ok, table_id, time}` where `time` is a list containing time elapsed during the extraction process
  (i.e. `[hour, minute, second, microsecond]`) when the timer argument is set to true. The `table_id` is used to access data for that particular ETS process with the various access functions of the
  `Xlsxir` module.

  Cells containing formulas in the worksheet are extracted as either a `string`, `integer` or `float` depending on the resulting value of the cell.
  Cells containing an ISO 8601 date format are extracted and converted to Erlang `:calendar.date()` format (i.e. `{year, month, day}`).

  ## Parameters
  - `path` - file path of a `.xlsx` file type in `string` format
  - `index` - index of worksheet from within the Excel workbook to be parsed (zero-based index)
  - `timer` - boolean flag that tracts extraction process time and returns it when set to `true`. Defalut value is `false`.

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

        iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
        iex> table_id |> Xlsxir.Worksheet.alive?
        true
        iex> table_id |> Xlsxir.close
        :ok

  ## Example
  Extract all worksheets in an example file named `test.xlsx` located in `./test/test_data`:

        iex> results = Xlsxir.multi_extract("./test/test_data/test.xlsx")
        iex> alive_ids = Enum.map(results, fn {:ok, table_id} -> table_id |> Xlsxir.Worksheet.alive? end)
        iex> Enum.all?(alive_ids)
        true
        iex> Enum.map(alive_ids, &Xlsxir.close/1) |> Enum.all?(fn result -> result == :ok end)
        true

  ## Example
  Extract all worksheets in an example file named `test.xlsx` located in `./test/test_data` with timer:

        iex> results = Xlsxir.multi_extract("./test/test_data/test.xlsx", nil, true)
        iex> alive_ids = Enum.map(results, fn {:ok, table_id, _timer} -> table_id |> Xlsxir.Worksheet.alive? end)
        iex> Enum.all?(alive_ids)
        true
        iex> Enum.map(alive_ids, &Xlsxir.close/1) |> Enum.all?(fn result -> result == :ok end)
        true
  """
  def multi_extract(path, index \\ nil, timer \\ false) do
    case is_nil(index) do
      true ->
        case Unzip.validate_path_all_indexes(path) do
          {:ok, indexes} ->
            Enum.reduce(indexes, [], fn i, acc ->
              acc ++ [multi_extract(path, i, timer)]
            end)
          {:error, reason} -> {:error, reason}
        end
      false ->
        if timer, do: Timer.start

        case Unzip.validate_path_and_index(path, index) do
          {:ok, file}      -> Unzip.xml_file_list(index)
          |> Unzip.extract_xml_to_file(file)
          |> case do
            {:ok, file_paths} -> do_multi_extract(file_paths, index, timer)
            {:error, reason}  -> {:error, reason}
          end
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_multi_extract(file_paths, index, timer) do
      Enum.each(file_paths, fn file ->
      case file do
        'temp/xl/sharedStrings.xml' -> SaxParser.parse(to_string(file), :string)
        'temp/xl/styles.xml'        -> SaxParser.parse(to_string(file), :style)
        _                           -> nil
      end
    end)

    {:ok, table_id} = SaxParser.parse("temp/xl/worksheets/sheet#{index + 1}.xml", :multi)
    Unzip.delete_dir

    if timer, do: {:ok, table_id, Timer.stop}, else: {:ok, table_id}
  end

  @doc """
  Accesses ETS process and returns data formatted as a list of row value lists.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> Xlsxir.get_list
          [["string one", "string two", 10, 20, {2016, 1, 1}]]
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> table_id |> Xlsxir.get_list
          [["string one", "string two", 10, 20, {2016, 1, 1}]]
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_list(table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> Enum.sort
    |> Enum.map(fn [_num, row] -> row
                                  |> Enum.map(fn [_ref, val] -> val end)
                                  end)
  end

  @doc """
  Accesses ETS process and returns data formatted as a map of cell references and values.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> Xlsxir.get_map
          %{ "A1" => "string one", "B1" => "string two", "C1" => 10, "D1" => 20, "E1" => {2016,1,1}}
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> table_id |> Xlsxir.get_map
          %{ "A1" => "string one", "B1" => "string two", "C1" => 10, "D1" => 20, "E1" => {2016,1,1}}
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_map(table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> Enum.reduce(%{}, fn [_num, row], acc ->
         row
         |> Enum.reduce(%{}, fn [ref, val], acc2 -> Map.put(acc2, ref, val) end)
         |> Enum.into(acc)
       end)
  end

  @doc """
  Accesses ETS process and returns an indexed map which functions like a multi-dimensional array in other languages.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> mda = Xlsxir.get_mda
          %{0 => %{0 => "string one", 1 => "string two", 2 => 10, 3 => 20, 4 => {2016,1,1}}}
          iex> mda[0][0]
          "string one"
          iex> mda[0][2]
          10
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> mda = table_id |> Xlsxir.get_mda
          %{0 => %{0 => "string one", 1 => "string two", 2 => 10, 3 => 20, 4 => {2016,1,1}}}
          iex> mda[0][0]
          "string one"
          iex> mda[0][2]
          10
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_mda(table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> convert_to_indexed_map(%{})
  end

  defp convert_to_indexed_map([], map), do: map

  defp convert_to_indexed_map([h|t], map) do
    Index.new
    row_index = Enum.at(h, 0)
                |> Kernel.-(1)

    add_row   = Enum.at(h,1)
                |> Enum.reduce(%{}, fn cell, acc ->
                      Index.increment_1
                      Map.put(acc, Index.get - 1, Enum.at(cell, 1))
                    end)

    Index.delete
    updated_map = Map.put(map, row_index, add_row)
    convert_to_indexed_map(t, updated_map)
  end


  @doc """
  Accesses ETS process and returns value of specified cell.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`
  - `cell_ref` - Reference name of cell to be returned in `string` format (i.e. `"A1"`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> Xlsxir.get_cell("A1")
          "string one"
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> table_id |> Xlsxir.get_cell("A1")
          "string one"
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_cell(cell_ref), do: do_get_cell(cell_ref)

  @doc """
  See `get_cell/1` documentation.
  """
  def get_cell(table_id, cell_ref), do: do_get_cell(cell_ref, table_id)

  defp do_get_cell(cell_ref, table_id \\ :worksheet) do
    [[row_num]] = ~r/\d+/ |> Regex.scan(cell_ref)
    row_num     = row_num |> String.to_integer
    [[row]]     = :ets.match(table_id, {row_num, :"$1"})

    row
    |> Enum.filter(fn [ref, _val] -> ref == cell_ref end)
    |> List.first
    |> Enum.at(1)
  end

  @doc """
  Accesses `:worksheet` ETS process and returns values of specified row in a `list`.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`
  - `row` - Reference name of row to be returned in `integer` format (i.e. `1`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> Xlsxir.get_row(1)
          ["string one", "string two", 10, 20, {2016, 1, 1}]
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> table_id |> Xlsxir.get_row(1)
          ["string one", "string two", 10, 20, {2016, 1, 1}]
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_row(row), do: do_get_row(row)

  @doc """
  See `get_row/1` documentation.
  """
  def get_row(table_id, row), do: do_get_row(row, table_id)

  defp do_get_row(row, table_id \\ :worksheet) do
    [[row]] = :ets.match(table_id, {row, :"$1"})

    row
    |> Enum.map(fn [_ref, val] -> val end)
  end

  @doc """
  Accesses `:worksheet` ETS process and returns values of specified column in a `list`.

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`
  - `col` - Reference name of column to be returned in `string` format (i.e. `"A"`)

  ## Example
  An example file named `test.xlsx` located in `./test/test_data` containing the following:
  - cell 'A1' -> "string one"
  - cell 'B1' -> "string two"
  - cell 'C1' -> integer of 10
  - cell 'D1' -> formula of "4 * 5"
  - cell 'E1' -> date of 1/1/2016 or Excel date serial of 42370

          iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
          :ok
          iex> Xlsxir.get_col("A")
          ["string one"]
          iex> Xlsxir.close
          :ok

          iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
          iex> table_id |> Xlsxir.get_col("A")
          ["string one"]
          iex> table_id |> Xlsxir.close
          :ok
  """
  def get_col(col), do: do_get_col(col)

  @doc """
  See `get_col/1` documentation.
  """
  def get_col(table_id, col), do: do_get_col(col, table_id)

  defp do_get_col(col, table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> Enum.sort
    |> Enum.map(fn [_num, row] -> row
                                  |> Enum.filter_map(fn [ref, _val] ->
                                       Regex.scan(~r/[A-Z]+/i, ref) == [[col]] end,
                                       fn [_ref, val] -> val
                                     end)
                                end)
    |> List.flatten
  end

  @doc """
  See `get_multi_info\2` documentation.
  """
  def get_info(num_type \\ :all) do
    case num_type do
      :rows  -> row_num
      :cols  -> col_num
      :cells -> cell_num
      _      -> [
                  rows:  row_num,
                  cols:  col_num,
                  cells: cell_num
                ]
    end
  end

  @doc """
  Returns count data based on `num_type` specified:
  - `:rows` - Returns number of rows contained in worksheet
  - `:cols` - Returns number of columns contained in worksheet
  - `:cells` - Returns number of cells contained in worksheet
  - `:all` - Returns a keyword list containing all of the above

  ## Parameters
  - `table_id` - table identifier of ETS process to be accessed, defaults to `:worksheet`
  - `num_type` - type of count data to be returned (see above), defaults to `:all`
  """
  def get_multi_info(table_id, num_type \\ :all) do
    case num_type do
    :rows  -> row_num(table_id)
    :cols  -> col_num(table_id)
    :cells -> cell_num(table_id)
    _      -> [
                rows:  row_num(table_id),
                cols:  col_num(table_id),
                cells: cell_num(table_id)
              ]
    end
  end

  defp row_num(table_id \\ :worksheet) do
    :ets.info(table_id, :size)
  end

  defp col_num(table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> Enum.map(fn [_num, row] -> Enum.count(row) end)
    |> Enum.max
  end

  defp cell_num(table_id \\ :worksheet) do
    :ets.match(table_id, {:"$1", :"$2"})
    |> Enum.reduce(0, fn [_num, row], acc -> acc + Enum.count(row) end)
  end

  @doc """
  Deletes ETS process `:worksheet` and returns `:ok` if successful.

  ## Example
  Extract first worksheet in an example file named `test.xlsx` located in `./test/test_data`:

      iex> Xlsxir.extract("./test/test_data/test.xlsx", 0)
      :ok
      iex> Xlsxir.close
      :ok

      iex> {:ok, table_id} = Xlsxir.multi_extract("./test/test_data/test.xlsx", 0)
      iex> Xlsxir.close(table_id)
      :ok
  """
  def close(table_id \\ :worksheet) do
    Worksheet.delete(table_id)
    |> case do
         false -> raise "Unable to close worksheet"
         true  -> :ok
       end
  end

end
