defmodule Xlsxir.ParseStyle do
  @moduledoc """
  Holds the SAX event instructions for parsing style data via `Xlsxir.SaxParser.parse/2`
  """

  # the following module attributes hold `numStyleId`s for standard number styles, grouping them between numbers and dates
  @num [
    0,
    1,
    2,
    3,
    4,
    9,
    10,
    11,
    12,
    13,
    37,
    38,
    39,
    40,
    44,
    48,
    49,
    56,
    58,
    59,
    60,
    61,
    62,
    67,
    68,
    69,
    70
  ]
  @date [14, 15, 16, 17, 18, 19, 20, 21, 22, 27, 30, 36, 45, 46, 47, 50, 55, 57]

  defstruct custom_style: %{}, cellxfs: false, index: 0, tid: nil, num_fmt_ids: []

  @doc """
  Sax event utilized by `Xlsxir.SaxParser.parse/2`. Takes a pattern and the current state of a struct and recursivly parses the
  styles XML file, ultimately saving each parsed style type to the ETS process. The style types generated are `nil` for numbers and `'d'` for dates.

  ## Parameters

  - pattern - the XML pattern of the event to match upon
  - state - the state of the `%Xlsxir.ParseStyle{}` struct which temporarily holds each `numFmtId` and its associated `formatCode` for custom format types

  ## Example
  Recursively sends style types generated from parsing the `xl/sharedStrings.xml` file to ETS process. The data can ultimately
  be retreived from the ETS table (i.e. `:ets.lookup(tid, 0)` would return `nil` or `'d'` depending on each style type generated).
  """
  def sax_event_handler(:startDocument, _state) do
    %__MODULE__{tid: GenServer.call(Xlsxir.StateManager, :new_table)}
  end

  def sax_event_handler({:startElement, _, ~c"cellXfs", _, _}, state) do
    %{state | cellxfs: true}
  end

  def sax_event_handler({:endElement, _, ~c"cellXfs", _}, state) do
    %{state | cellxfs: false}
  end

  def sax_event_handler(
        {:startElement, _, ~c"xf", _, xml_attr},
        %__MODULE__{num_fmt_ids: num_fmt_ids} = state
      ) do
    if state.cellxfs do
      xml_attr
      |> Enum.filter(fn attr ->
        case attr do
          {:attribute, ~c"numFmtId", _, _, _} -> true
          _ -> false
        end
      end)
      |> case do
        [{_, _, _, _, id}] ->
          %{state | num_fmt_ids: num_fmt_ids ++ [id]}

        _ ->
          %{state | num_fmt_ids: num_fmt_ids ++ [~c"0"]}
      end
    else
      state
    end
  end

  def sax_event_handler(
        {:startElement, _, ~c"numFmt", _, xml_attr},
        %__MODULE__{custom_style: custom_style} = state
      ) do
    temp =
      Enum.reduce(xml_attr, %{}, fn attr, acc ->
        case attr do
          {:attribute, ~c"numFmtId", _, _, id} -> Map.put(acc, :id, id)
          {:attribute, ~c"formatCode", _, _, cd} -> Map.put(acc, :cd, cd)
          _ -> nil
        end
      end)

    %{state | custom_style: Map.put(custom_style, temp[:id], temp[:cd])}
  end

  def sax_event_handler(:endDocument, %__MODULE__{} = state) do
    %__MODULE__{custom_style: custom_style, num_fmt_ids: num_fmt_ids, index: index, tid: tid} =
      state

    custom_type = custom_style_handler(custom_style)

    inc =
      Enum.reduce(num_fmt_ids, 0, fn style_type, acc ->
        case List.to_integer(style_type) do
          i when i in @num -> :ets.insert(tid, {index + acc, nil})
          i when i in @date -> :ets.insert(tid, {index + acc, ~c"d"})
          _ -> add_custom_style(tid, style_type, custom_type, index + acc)
        end

        acc + 1
      end)

    %{state | index: index + inc}
  end

  def sax_event_handler(_, state), do: state

  defp custom_style_handler(custom_style) do
    custom_style
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      cond do
        String.match?(to_string(v), ~r/\bred\b/i) -> Map.put_new(acc, k, nil)
        String.match?(to_string(v), ~r/[dhmsy]/i) -> Map.put_new(acc, k, ~c"d")
        true -> Map.put_new(acc, k, nil)
      end
    end)
  end

  defp add_custom_style(tid, style_type, custom_type, index) do
    if Map.has_key?(custom_type, style_type) do
      :ets.insert(tid, {index, custom_type[style_type]})
    else
      raise "Unsupported style type: #{style_type}. See doc page \"Number Styles\" for more info."
    end
  end
end
