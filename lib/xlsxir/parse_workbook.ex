defmodule Xlsxir.ParseWorkbook do
  @moduledoc """
  Holds the SAX event instructions for parsing style data via `Xlsxir.SaxParser.parse/2`
  """

  @doc """
  sheets has multiple sheet map which consists of name, sheet_id and rid
  """
  defstruct sheets: [], tid: nil

  def sax_event_handler(:startDocument, _state) do
    %__MODULE__{tid: GenServer.call(Xlsxir.StateManager, :new_table)}
  end

  def sax_event_handler({:startElement, _, 'sheet', _, xml_attrs}, state) do
    sheet =
      Enum.reduce(
        xml_attrs,
        %{name: nil, sheet_id: nil, rid: nil, index: length(state.sheets)},
        fn attr, sheet ->
          case attr do
            {:attribute, 'name', _, _, name} ->
              %{sheet | name: name |> to_string}

            {:attribute, 'sheetId', _, _, sheet_id} ->
              {sheet_id, _} = sheet_id |> to_string |> Integer.parse()
              %{sheet | sheet_id: sheet_id}

            {:attribute, 'id', _, _, rid} ->
              %{sheet | rid: to_string(rid)}

            _ ->
              sheet
          end
        end
      )

    %__MODULE__{state | sheets: [sheet | state.sheets]}
  end

  def sax_event_handler(:endDocument, %__MODULE__{tid: tid} = state) do
    Enum.map(state.sheets, fn %{rid: rid, name: name, index: index} ->
      :ets.insert(tid, {rid, name, index})
    end)

    state
  end

  def sax_event_handler(_, state), do: state
end
