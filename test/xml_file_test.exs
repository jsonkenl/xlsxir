defmodule XmlFileTest do
  use ExUnit.Case

  def no_shared_path(), do: "./test/test_data/noShared.xlsx"

  test "open memory XmlFile" do
    assert {:ok, _file_pid} =
             Xlsxir.XmlFile.open(%Xlsxir.XmlFile{
               content: File.read!("./test/test_data/test/xl/styles.xml")
             })
  end

  test "open filepath XmlFile" do
    assert {:ok, _file_pid} =
             Xlsxir.XmlFile.open(%Xlsxir.XmlFile{path: "./test/test_data/test/xl/styles.xml"})
  end

  test "parses xlsx without sharedStings and styles" do
    # here is a spec which sayeth there shalt always be shared strings:
    #
    #  https://msdn.microsoft.com/en-us/library/office/gg278314.aspx

    # here is a blog which sayeth, screw the spec
    #
    # http://ericwhite.com/blog/advice-when-generating-spreadsheets-use-inline-strings-not-shared-strings/
    # http://ericwhite.com/blog/when-writing-spreadsheets-a-comparison-of-using-the-shared-string-table-to-using-in-line-strings/

    # i'm running across xlsx produced by developers who read the blog.

    s = Xlsxir.stream_list(no_shared_path(), 0)
    assert %Stream{} = s
    assert 3 == s |> Enum.map(& &1) |> length
  end
end
