defmodule LeadingCellsTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 10_000
  @spreadsheet "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  @relationships "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

  setup do
    directory =
      Path.join(System.tmp_dir!(), "xlsxir-leading-#{System.unique_integer([:positive])}")

    owner = Process.whereis(Xlsxir.StateManager)
    tables = :ets.all()

    # Also clean tables allocated before an extraction failure returns their IDs.
    on_exit(fn ->
      for tid <- :ets.all() -- tables, :ets.info(tid, :owner) == owner do
        :ets.delete(tid)
      end

      File.rm_rf!(directory)
    end)

    File.mkdir_p!(directory)
    {:ok, directory: directory}
  end

  # Synthetic regression for #132. XFD is a column-boundary case, not a load test.
  for mode <- [:memory, :file],
      {column, index} <- [
        {"A", 1},
        {"B", 2},
        {"Z", 26},
        {"AA", 27},
        {"AB", 28},
        {"AZ", 52},
        {"BA", 53},
        {"XFD", 16_384}
      ] do
    test "#{column} leading cells retain positions in #{mode} mode",
         %{directory: directory} do
      column = unquote(column)
      index = unquote(index)
      path = create_workbook(directory, ~s(<c r="#{column}12"><v>42</v></c>))
      options = [extract_to: unquote(mode), extract_base_dir: directory]
      {:ok, tid} = Xlsxir.multi_extract(path, 0, false, nil, options)
      on_exit(fn -> Xlsxir.close(tid) end)
      expected = List.duplicate(nil, index - 1) ++ [42]

      assert Xlsxir.get_list(tid) == [expected]
      expected_columns = expected |> Enum.with_index() |> Map.new(fn {v, i} -> {i, v} end)
      assert Xlsxir.get_mda(tid) == %{11 => expected_columns}
      assert Xlsxir.get_cell(tid, "#{column}12") == 42
      assert Xlsxir.get_info(tid, :rows) == 1
      assert Xlsxir.get_info(tid, :cells) == index
      assert Xlsxir.get_info(tid, :cols) == index

      # Streaming has a separate gap-preservation fix scheduled in A4.
      assert Enum.to_list(Xlsxir.stream_list(path, 0, options)) == [[42]]
    end
  end

  for mode <- [:memory, :file] do
    test "leading and internal gaps compose in #{mode} mode", %{directory: directory} do
      cells = ~s(<c r="AA12"><v>42</v></c><c r="AC12"><v>84</v></c>)
      path = create_workbook(directory, cells)
      options = [extract_to: unquote(mode), extract_base_dir: directory]
      {:ok, tid} = Xlsxir.multi_extract(path, 0, false, nil, options)
      on_exit(fn -> Xlsxir.close(tid) end)

      assert Xlsxir.get_list(tid) == [List.duplicate(nil, 26) ++ [42, nil, 84]]
      assert Xlsxir.get_mda(tid)[11][26] == 42
      assert Xlsxir.get_mda(tid)[11][27] == nil
      assert Xlsxir.get_mda(tid)[11][28] == 84
      assert Xlsxir.get_map(tid)["AB12"] == nil
      assert Enum.to_list(Xlsxir.stream_list(path, 0, options)) == [[42, 84]]
    end
  end

  defp create_workbook(directory, cells) do
    parts = [
      {"[Content_Types].xml",
       """
       <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
         <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
         <Default Extension="xml" ContentType="application/xml"/>
         <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
         <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
       </Types>
       """},
      {"_rels/.rels",
       """
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
         <Relationship Id="workbook" Type="#{@relationships}/officeDocument" Target="xl/workbook.xml"/>
       </Relationships>
       """},
      {"xl/workbook.xml",
       """
       <workbook xmlns="#{@spreadsheet}" xmlns:r="#{@relationships}">
         <sheets><sheet name="Example" sheetId="1" r:id="rId1"/></sheets>
       </workbook>
       """},
      {"xl/_rels/workbook.xml.rels",
       """
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
         <Relationship Id="rId1" Type="#{@relationships}/worksheet" Target="worksheets/sheet1.xml"/>
       </Relationships>
       """},
      {"xl/worksheets/sheet1.xml",
       """
       <worksheet xmlns="#{@spreadsheet}"><sheetData>
         <row r="1"/>
         <row r="12">#{cells}</row>
       </sheetData></worksheet>
       """}
    ]

    path = Path.join(directory, "leading-cells.xlsx")
    files = Enum.map(parts, fn {name, content} -> {String.to_charlist(name), content} end)
    {:ok, _} = :zip.create(String.to_charlist(path), files)
    path
  end
end
