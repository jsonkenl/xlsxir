defmodule Xlsxir.ParseWorksheet do
  alias Xlsxir.{ConvertDate, ConvertDateTime, SaxError}
  import Xlsxir.ConvertDate, only: [convert_char_number: 1]
  require Logger

  @moduledoc """
  Holds the SAX event instructions for parsing worksheet data via `Xlsxir.SaxParser.parse/2`
  """

  defstruct row: [],
            cell_ref: "",
            data_type: "",
            num_style: "",
            value: "",
            value_type: nil,
            max_rows: nil,
            tid: nil

  @doc """
  Sax event utilized by `Xlsxir.SaxParser.parse/2`. Takes a pattern and the current state of a struct and recursivly parses the
  worksheet XML file, ultimately saving a list of cell references and their assocated values to the ETS process.

  ## Parameters

  - `arg1` - the XML pattern of the event to match upon
  - `state` - the state of the `%Xlsxir.ParseWorksheet{}` struct which temporarily holds applicable data of the current row being parsed

  ## Example
  Each entry in the list created consists of a list containing a cell reference string and the associated value (i.e. `[["A1", "string one"], ...]`).
  """
  def sax_event_handler(
        :startDocument,
        _state,
        %{max_rows: max_rows, workbook: workbook_tid},
        xml_name
      ) do
    tid = GenServer.call(Xlsxir.StateManager, :new_table)

    "sheet" <> remained = xml_name
    {sheet_id, _} = Integer.parse(remained)

    worksheet_name =
      List.foldl(:ets.lookup(workbook_tid, sheet_id), nil, fn value, _ ->
        case value do
          {_, worksheet_name} -> worksheet_name
          _ -> nil
        end
      end)

    # [{_, worksheet_name} | _] = :ets.lookup(workbook_tid, rid)

    :ets.insert(tid, {:info, :worksheet_name, worksheet_name})

    %__MODULE__{tid: tid, max_rows: max_rows}
  end

  def sax_event_handler(
        {:startElement, _, ~c"row", _, _},
        %__MODULE__{tid: tid, max_rows: max_rows},
        _excel,
        _
      ) do
    %__MODULE__{tid: tid, max_rows: max_rows}
  end

  def sax_event_handler({:startElement, _, ~c"c", _, xml_attr}, state, %{styles: styles_tid}, _) do
    a =
      Enum.reduce(xml_attr, %{}, fn attr, acc ->
        case attr do
          {:attribute, ~c"s", _, _, style} ->
            Map.put(acc, "s", find_styles(styles_tid, List.to_integer(style)))

          {:attribute, key, _, _, ref} ->
            Map.put(acc, to_string(key), ref)
        end
      end)

    {cell_ref, num_style, data_type} = {a["r"], a["s"], a["t"]}

    %{state | cell_ref: cell_ref, num_style: num_style, data_type: data_type}
  end

  def sax_event_handler({:startElement, _, ~c"f", _, _}, state, _, _) do
    %{state | value_type: :formula}
  end

  def sax_event_handler({:startElement, _, el, _, _}, state, _, _) when el in [~c"v", ~c"t"] do
    %{state | value_type: :value}
  end

  def sax_event_handler({:endElement, _, el, _, _}, state, _, _) when el in [~c"f", ~c"v", ~c"t"] do
    %{state | value_type: nil}
  end

  def sax_event_handler({:startElement, _, ~c"is", _, _}, state, _, _),
    do: %{state | value_type: :value}

  def sax_event_handler({:characters, value}, state, _, _) do
    case state do
      nil -> nil
      %{value_type: :value} -> %{state | value: value}
      _ -> state
    end
  end

  def sax_event_handler({:endElement, _, ~c"c", _}, %__MODULE__{row: row} = state, excel, _) do
    cell_value = format_cell_value(excel, [state.data_type, state.num_style, state.value])
    new_cell = [to_string(state.cell_ref), cell_value]

    %{
      state
      | row: [new_cell | row],
        cell_ref: "",
        data_type: "",
        num_style: "",
        value: ""
    }
  end

  def sax_event_handler(
        {:endElement, _, ~c"row", _},
        %__MODULE__{tid: tid, max_rows: max_rows} = state,
        _excel,
        _
      ) do
    unless Enum.empty?(state.row) do
      [[row]] = ~r/\d+/ |> Regex.scan(state.row |> List.first() |> List.first())
      row = row |> String.to_integer()
      value = state.row |> Enum.reverse() |> fill_nil()

      :ets.insert(tid, {row, value})
      if !is_nil(max_rows) and row == max_rows, do: raise(SaxError, state: state)
    end

    state
  end

  def sax_event_handler(_, state, _, _), do: state

  defp fill_nil(rows) do
    Enum.reduce(rows, {[], nil}, fn [ref, val], {values, previous} ->
      line = ~r/\d+$/ |> Regex.run(ref) |> List.first()

      empty_cells =
        cond do
          is_nil(previous) && !Regex.match?(~r/^A\d/, ref) ->
            fill_empty_cells("A#{line}", ref, line, [])

          !is_nil(previous) && !is_next_col(ref, previous) ->
            fill_empty_cells(next_col(previous), ref, line, [])

          true ->
            []
        end

      {values ++ empty_cells ++ [[ref, val]], ref}
    end)
    |> elem(0)
  end

  def column_from_index(index, column) when index > 0 do
    modulo = rem(index - 1, 26)
    column = [65 + modulo | column]
    column_from_index(div(index - modulo, 26), column)
  end

  def column_from_index(_, column), do: to_string(column)

  defp is_next_col(current, previous) do
    current == next_col(previous)
  end

  def next_col(ref) do
    [chars, line] = Regex.run(~r/^([A-Z]+)(\d+)/, ref, capture: :all_but_first)
    chars = chars |> String.to_charlist()

    col_index =
      Enum.reduce(chars, 0, fn char, acc ->
        acc = acc * 26
        acc + char - 65 + 1
      end)

    "#{column_from_index(col_index + 1, ~c"")}#{line}"
  end

  def fill_empty_cells(from, from, _line, cells), do: Enum.reverse(cells)

  def fill_empty_cells(from, to, line, cells) do
    next_ref = next_col(from)

    if next_ref == to do
      fill_empty_cells(to, to, line, [[from, nil] | cells])
    else
      fill_empty_cells(next_ref, to, line, [[from, nil] | cells])
    end
  end

  defp format_cell_value(%{shared_strings: strings_tid}, list) do
    case list do
      # Cell with no value attribute
      [_, _, nil] -> nil
      # Empty cell with assigned attribute
      [_, _, ""] -> nil
      # Type error
      [~c"e", _, e] -> List.to_string(e)
      # Type string
      [~c"s", _, i] -> find_string(strings_tid, List.to_integer(i))
      # Type number
      [nil, nil, n] -> convert_char_number(n)
      [~c"n", nil, n] -> convert_char_number(n)
      # ISO 8601 type date
      [nil, ~c"d", d] -> convert_date_or_time(d)
      [~c"n", ~c"d", d] -> convert_date_or_time(d)
      [~c"d", ~c"d", d] -> convert_iso_date(d)
      # Type formula w/ string
      [~c"str", _, s] -> List.to_string(s)
      # Type boolean
      [~c"b", _, s] -> s == ~c"1"
      # Type string
      [~c"inlineStr", _, s] -> List.to_string(s)
      # Unmapped type
      _ -> raise "Unmapped attribute #{Enum.at(list, 0)}. Unable to process"
    end
  end

  defp convert_iso_date(value) do
    str = value |> List.to_string()

    with {:ok, date} <- str |> Date.from_iso8601() do
      date |> Date.to_erl()
    else
      {:error, _} ->
        with {:ok, datetime} <- str |> NaiveDateTime.from_iso8601() do
          datetime
        else
          {:error, _} -> str
        end
    end
  end

  defp convert_date_or_time(value) do
    str = List.to_string(value)

    if str == "0" || String.match?(str, ~r/\d\.\d+/) do
      ConvertDateTime.from_charlist(value)
    else
      ConvertDate.from_serial(value)
    end
  end

  defp find_styles(nil, _index), do: nil

  defp find_styles(tid, index) do
    tid
    |> :ets.lookup(index)
    |> List.first()
    |> case do
      nil ->
        nil

      {_, i} ->
        i
    end
  end

  defp find_string(nil, _index), do: nil

  defp find_string(tid, index) do
    tid
    |> :ets.lookup(index)
    |> List.first()
    |> elem(1)
  end
end
