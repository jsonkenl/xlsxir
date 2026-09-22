defmodule RelationshipIdsTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 10_000
  @spreadsheet "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  @relationships "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

  setup do
    directory =
      Path.join(System.tmp_dir!(), "xlsxir-rids-#{System.unique_integer([:positive])}")

    owner = Process.whereis(Xlsxir.StateManager)
    tables = :ets.all()

    # Initialization failures can leave tables whose IDs were never returned.
    # These tests run synchronously; preserve every table present before the test.
    on_exit(fn ->
      for tid <- :ets.all() -- tables, :ets.info(tid, :owner) == owner do
        :ets.delete(tid)
      end

      File.rm_rf!(directory)
    end)

    File.mkdir_p!(directory)
    {:ok, directory: directory}
  end

  # Synthetic coverage of #106 and @coop's #137; no customer workbook data.
  for rid <- ["R1", "rIdSheet1", "rId1"] do
    test "sheet maps omit the unused relationship ID #{rid}" do
      attrs = [
        {:attribute, String.to_charlist("name"), [], [], String.to_charlist("Example")},
        {:attribute, String.to_charlist("sheetId"), [], [], String.to_charlist("1")},
        {:attribute, String.to_charlist("id"), [], [], String.to_charlist(unquote(rid))}
      ]

      state =
        Xlsxir.ParseWorkbook.sax_event_handler(
          {:startElement, [], String.to_charlist("sheet"), [], attrs},
          %Xlsxir.ParseWorkbook{}
        )

      assert state.sheets == [%{name: "Example", sheet_id: 1}]
    end

    for mode <- [:memory, :file], access <- [:materialized, :stream] do
      test "#{access} accepts #{rid} with #{mode} extraction", %{directory: directory} do
        path = create_workbook(directory, unquote(rid))
        options = [extract_to: unquote(mode), extract_base_dir: directory]
        expected = [["Header", "Value"], ["Example", 42]]

        case unquote(access) do
          :materialized ->
            {:ok, tid} = Xlsxir.multi_extract(path, 0, false, nil, options)
            on_exit(fn -> Xlsxir.close(tid) end)
            assert Xlsxir.get_info(tid, :name) == "Example"
            assert Xlsxir.get_list(tid) == expected

          :stream ->
            assert Enum.to_list(Xlsxir.stream_list(path, 0, options)) == expected
        end
      end
    end
  end

  defp create_workbook(directory, rid) do
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
         <sheets><sheet name="Example" sheetId="1" r:id="#{rid}"/></sheets>
       </workbook>
       """},
      {"xl/_rels/workbook.xml.rels",
       """
       <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
         <Relationship Id="#{rid}" Type="#{@relationships}/worksheet" Target="worksheets/sheet1.xml"/>
       </Relationships>
       """},
      {"xl/worksheets/sheet1.xml",
       """
       <worksheet xmlns="#{@spreadsheet}"><sheetData>
         <row r="1">
           <c r="A1" t="inlineStr"><is><t>Header</t></is></c>
           <c r="B1" t="inlineStr"><is><t>Value</t></is></c>
         </row>
         <row r="2">
           <c r="A2" t="inlineStr"><is><t>Example</t></is></c>
           <c r="B2"><v>42</v></c>
         </row>
       </sheetData></worksheet>
       """}
    ]

    path = Path.join(directory, "relationship-id.xlsx")
    files = Enum.map(parts, fn {name, content} -> {String.to_charlist(name), content} end)
    {:ok, _} = :zip.create(String.to_charlist(path), files)
    path
  end
end
