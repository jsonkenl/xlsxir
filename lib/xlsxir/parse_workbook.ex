defmodule Xlsxir.ParseWorkbook do
  @moduledoc """
  Holds the SAX event instructions for parsing style data via `Xlsxir.SaxParser.parse/2`
  """

  @doc """
  Sheet tags come in the order they appear in the spreadsheet.
  """
  defstruct sheet_number: 1, tid: nil

  def sax_event_handler(:startDocument, _state) do
    %__MODULE__{tid: GenServer.call(Xlsxir.StateManager, :new_table)}
  end

  def sax_event_handler({:startElement, _, 'sheet', _, xml_attrs}, state) do
    sheet_name =
      Enum.find_value(xml_attrs, fn
        {:attribute, 'name', _, _, name} -> to_string(name)
        _ -> nil
      end)

    :ets.insert(state.tid, {state.sheet_number, sheet_name})
    %__MODULE__{state | sheet_number: state.sheet_number + 1}
  end

  def sax_event_handler(_, state), do: state
end
