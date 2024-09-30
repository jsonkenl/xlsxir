defmodule XlsxirTest do
  use ExUnit.Case

  import Xlsxir

  def path(), do: "./test/test_data/test.xlsx"
  def rb_path(), do: "./test/test_data/red_black.xlsx"
  def missing_styles_path(), do: "./test/test_data/missing_styles.xlsx"
  def apple_numbers_path(), do: "./test/test_data/test_apple_numbers.xlsx"

  test "second worksheet is parsed with index argument of 1" do
    {:ok, pid} = extract(path(), 1)
    assert get_list(pid) == [[1, 2], [3, 4]]
    close(pid)
  end

  test "able to parse maximum number of columns" do
    {:ok, pid} = extract(path(), 2)
    assert get_cell(pid, "XFD1") == 16384
    close(pid)
  end

  test "able to parse maximum number of rows" do
    {:ok, pid} = extract(path(), 3)
    assert get_cell(pid, "A1048576") == 1_048_576
    close(pid)
  end

  test "able to parse cells with errors" do
    {:ok, pid} = extract(path(), 4)
    assert get_list(pid) == [["#DIV/0!", "#REF!", "#NUM!", "#VALUE!"]]
    close(pid)
  end

  test "able to parse custom formats" do
    {:ok, pid} = extract(path(), 5)

    assert get_list(pid) == [
             [-123.45, 67.89, {2015, 1, 1}, {2016, 12, 31}, {15, 12, 45}, ~N[2012-12-18 14:26:00]]
           ]

    close(pid)
  end

  test "able to parse with conditional formatting" do
    {:ok, pid} = extract(path(), 6)
    assert get_list(pid) == [["Conditional"]]
    close(pid)
  end

  test "able to parse with boolean values" do
    {:ok, pid} = extract(path(), 7)
    assert get_list(pid) == [[true, false]]
    close(pid)
  end

  test "peek file contents" do
    {:ok, pid} = peek(path(), 8, 10)
    assert get_cell(pid, "G10") == 8437
    assert get_info(pid, :rows) == 10
    close(pid)
  end

  test "get_cell returns nil for non-existent cells" do
    {:ok, pid} = extract(path(), 0)
    assert get_cell(pid, "A2") == nil
    assert get_cell(pid, "F1") == nil
    close(pid)
  end

  test "get_cell returns correct content even with rich text" do
    {:ok, pid} = extract(rb_path(), 0)
    assert get_cell(pid, "A1") == "RED: BLACK"
    assert get_cell(pid, "A2") == "Data"
    close(pid)
  end

  test "able to parse Apple Numbers Excel export" do
    {:ok, pid} = extract(apple_numbers_path(), 1)
    assert get_list(pid) == [[1, 2], [3, 4]]
    close(pid)
  end

  test "multi_extract/4" do
    res = multi_extract(path())
    {:ok, tid} = hd(res)
    assert 11 == Enum.count(res)
    assert [["string one", "string two", 10, 20, {2016, 1, 1}]] == get_list(tid)
  end

  def error_cell_path(), do: "./test/test_data/error-date.xlsx"

  test "error cells can be parsed properly1" do
    {:ok, pid} = extract(error_cell_path(), 0)
    close(pid)
  end

  test "empty cells are filled with nil" do
    {:ok, pid} = multi_extract(path(), 9)

    assert get_list(pid) == [
             [1, nil, 1, nil, 1, nil, nil, 1],
             [nil, 1, nil, nil, 1, nil, 1],
             [nil, nil, nil, nil, nil, 1, nil, nil, nil, 1],
             [1, 1, nil, 1]
           ]
  end

  test "empty reference cells are filled with nil" do
    {:ok, pid} = multi_extract(path(), 10)

    assert get_list(pid) == [
             [1, nil, 1, nil, 1, nil, nil, 1, nil, nil],
             [nil, 1, nil, nil, 1, nil, 1, nil, nil, nil],
             [nil, nil, nil, nil, nil, 1, nil, nil, nil, 1],
             [1, 1, nil, 1, nil, nil, nil, nil, nil, nil]
           ]
  end

  test "handles non-existent xlsx file gracefully" do
    {:error, _err} = multi_extract("this/file/does/not/exist.xlsx")
  end

  test "parses successfully even with columns that have no styles defined" do
    {:ok, pid} = extract(missing_styles_path(), 0)

    expected_rows = [
      ["Tag", "Type", "Status", "Commissioned"],
      ["abc123", "InProgress", "Complete", ~N[2019-06-21 02:39:11]]
    ]

    assert get_list(pid) == expected_rows
    close(pid)
  end

  test "parses cells with cell metadata successfully" do
    {:ok, pid} = multi_extract("./test/test_data/cell-metadata.xlsx", 0)
    assert get_list(pid) == [["hello"]]
  end

  # fixture obtained from https://github.com/OfficeDev/Open-XML-SDK test files
  test "parses cells with value metadata successfully" do
    {:ok, pid} = multi_extract("./test/test_data/value-metadata.xlsx", 0)

    assert [row1 | _] = get_list(pid)
    assert row1 == ["Filter rows", "Category", "Color", "Sales Amount"]
  end

  test "parses inlineStr inside `t` element" do
    {:ok, pid} = multi_extract("./test/test_data/inline-str.xlsx", 0)

    assert get_list(pid) == [
             ["foo", "bar"],
             [123, "baz"]
           ]
  end

  test "parses inline strings" do
    {:ok, pid} = multi_extract("test/test_data/noShared.xlsx", 0)
    on_exit(fn -> close(pid) end)
    map = get_map(pid)

    assert map["A1"] == "Generated Doc"
    assert map["B2"] == "pre 2008"
    assert map["B3"] == "https://msdn.microsoft.com/en-us/library/office/gg278314.aspx"
  end
end
