defmodule StreamTest do
  use ExUnit.Case

  import Xlsxir

  def path(), do: "./test/test_data/test.xlsx"

  test "produces a stream" do
    s = stream_list(path(), 8)
    assert %Stream{} = s
    assert 51 == s |> Enum.map(& &1) |> length
  end

  test "stream can run multiple times" do
    s = stream_list(path(), 8)
    assert %Stream{} = s
    # First run should proceed normally
    assert {:ok, _} = Task.yield(Task.async(fn -> s |> Stream.run() end), 2000)
    # second run will hang on missing fs resources (before fix) and hang (default 60s)
    assert {:ok, _} = Task.yield(Task.async(fn -> s |> Stream.run() end), 2000)
    # third run because reasons
    assert {:ok, _} = Task.yield(Task.async(fn -> s |> Stream.run() end), 2000)
  end
end
