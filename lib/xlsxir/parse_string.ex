defmodule Xlsxir.ParseString do
  @moduledoc """
  Holds the SAX event instructions for parsing sharedString data via `Xlsxir.SaxParser.parse/2`
  """

  defstruct empty_string: true, family: false, family_string: "", index: 0, tid: nil

  @doc """
  Sax event utilized by `Xlsxir.SaxParser.parse/2`. Takes a pattern and the current state of a struct and recursivly parses the
  sharedString XML file, ultimately saving each parsed string to the ETS process.

  ## Parameters

  - pattern - the XML pattern of the event to match on
  - state - current state of the `%Xlsxir.ParseString{}` struct

  ## Example
  Recursively sends strings from the `xl/sharedStrings.xml` file to ETS process. The data can ultimately
  be retreived from the ETS table (i.e. `:ets.lookup(tid, 0)` would return something like `"string 1"`).
  """
  def sax_event_handler(:startDocument, _state) do
    %__MODULE__{tid: GenServer.call(Xlsxir.StateManager, :new_table)}
  end

  def sax_event_handler({:startElement, _, ~c"si", _, _}, %__MODULE__{tid: tid, index: index}),
    do: %__MODULE__{tid: tid, index: index}

  def sax_event_handler({:startElement, _, ~c"family", _, _}, state) do
    %{state | family: true}
  end

  def sax_event_handler(
        {:characters, value},
        %__MODULE__{family_string: fam_str} = state
      ) do
    value = value |> to_string
    %{state | family_string: fam_str <> value}
  end

  def sax_event_handler(
        {:endElement, _, ~c"si", _},
        %__MODULE__{family_string: fam_str, tid: tid, index: index} = state
      ) do
    :ets.insert(tid, {index, fam_str})
    %{state | index: index + 1}
  end

  def sax_event_handler(_, state), do: state
end
