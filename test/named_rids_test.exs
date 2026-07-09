defmodule NamedRidsTest do
  use ExUnit.Case

  import Xlsxir

  # OOXML relationship ids are arbitrary NCNames, not necessarily "rId<n>".
  # The fixture's workbook declares its sheet as r:id="rIdSheet1" (produced
  # by a real-world freight-forwarder export) and stores every cell as an
  # inline string.
  def path(), do: "./test/test_data/named_rids.xlsx"

  test "parses workbooks with non-numeric sheet relationship ids" do
    {:ok, pid} = extract(path(), 0)
    assert get_info(pid, :name) == "Ocean AMS"
    close(pid)
  end

  test "parses inline string cells" do
    {:ok, pid} = extract(path(), 0)
    [header_row, first_row | _] = get_list(pid)
    assert Enum.take(header_row, 2) == ["houseBillNumber", "shipperName"]
    assert Enum.take(first_row, 2) == ["HBL0001", "ACME PLUSH CO"]
    close(pid)
  end
end
