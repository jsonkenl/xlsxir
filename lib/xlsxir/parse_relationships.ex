defmodule Xlsxir.ParseRelationships do
  @moduledoc """
  Holds the SAX event instructions for parsing relationship data via `Xlsxir.SaxParser.parse/2`
  """

  @doc """
  """
  defstruct worksheet_relationships: [], tid: nil

  def sax_event_handler(:startDocument, workbook_tid) do
    %__MODULE__{tid: workbook_tid}
  end

  @type_worksheet "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"

  def sax_event_handler({:startElement, _, 'Relationship', _, xml_attrs}, state) do
    relationship =
      Enum.reduce(xml_attrs, %{rid: nil, target: nil, type: nil}, fn attr, relationship ->
        case attr do
          {:attribute, 'Id', _, _, rid} ->
            %{relationship | rid: to_string(rid)}

          {:attribute, 'Type', _, _, type} ->
            %{relationship | type: to_string(type)}

          {:attribute, 'Target', _, _, target} ->
            %{relationship | target: to_string(target)}

          _ ->
            relationship
        end
      end)

    if relationship.type == @type_worksheet do
      %{state | worksheet_relationships: [relationship | state.worksheet_relationships]}
    else
      state
    end
  end

  def sax_event_handler(:endDocument, %__MODULE__{tid: tid} = state) do
    pairs = Enum.map(state.worksheet_relationships, fn rel -> {rel.rid, rel.target} end)
    :ets.insert(tid, {:worksheet_relationships, pairs})

    state
  end

  def sax_event_handler(_, state), do: state
end
