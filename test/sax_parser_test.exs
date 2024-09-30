defmodule SaxParserTest do
  use ExUnit.Case

  alias Xlsxir.SaxParser
  alias Xlsxir.XmlFile

  test "reads complex shared strings correctly" do
    xml_file = %XmlFile{content: File.read!("./test/test_data/complexStrings.xml")}
    {:ok, %{tid: tid}, _} = SaxParser.parse(xml_file, :string)

    assert find_string(tid, 0) == "FOO: BAR"
    assert find_string(tid, 1) == "BAZ"
  end

  defp find_string(tid, index) do
    :ets.lookup(tid, index)
    |> List.first()
    |> elem(1)
  end
end
