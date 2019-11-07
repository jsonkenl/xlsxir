defmodule Xlsxir.StreamWorksheet do
  @moduledoc """
  Holds the special SAX event instructions for parsing and streaming
  worksheet data rows via `Xlsxir.SaxParser.parse/2`

  Delegates other SAX event instructions to `Xlsxir.ParseWorksheet`
  """

  alias Xlsxir.ParseWorksheet

  @doc """
  Sax event utilized by `Xlsxir.SaxParser.parse/2`.

  Takes a pattern and the current state of a struct and recursivly parses the
  worksheet XML file.

  Blocks the process when a row is fully parsed, with cell references
  and their assocated values, then wait for a message from a parent process
  to callback and send the row data.

  ## Parameters

  - `sax_pattern` - the XML pattern of the event to match upon
  - `state` - the state of the `%Xlsxir.StreamWorksheet{}` struct which temporarily holds applicable data of the current row being parsed

  ## Example

  Each row data sent consists of a list containing a cell reference string
  and the associated value (i.e. `[["A1", "string one"], ...]`).
  """
  def sax_event_handler(sax_pattern, state, xlsx_file)

  def sax_event_handler(:startDocument, _state, %Xlsxir.XlsxFile{}) do
    %ParseWorksheet{}
  end

  def sax_event_handler({:endElement, _, 'row', _}, state, _xlsx_file) do
    unless Enum.empty?(state.row) do
      value = state.row |> Enum.reverse()

      # Wait for parent process to ask for the next row
      receive do
        {:get_next_row, from} -> send(from, {:next_row, value})
      end
    end

    state
  end

  def sax_event_handler(:endDocument, _state, _excel) do
    # If the end of the document is reached, and if the
    # parent process ask for a next row, sends the `end` message
    receive do
      {:get_next_row, from} -> send(from, {:end})
    end
  end

  # Delegates other SAX events to Xlsxir.ParseWorksheet
  def sax_event_handler(sax_event, state, xlsx_file) do
    ParseWorksheet.sax_event_handler(sax_event, state, xlsx_file)
  end
end
