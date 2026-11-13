defmodule WorksheetIdentityTest do
  use ExUnit.Case

  @moduletag timeout: 10_000
  @path Path.expand("test_data/issue93-elixlsx.xlsx", __DIR__)

  for mode <- [:memory, :file] do
    test "issue 93 preserves sheet names and data with #{mode} extraction" do
      directory =
        Path.join(System.tmp_dir!(), "xlsxir-issue93-#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf!(directory) end)
      options = [extract_to: unquote(mode), extract_base_dir: directory]
      results = Xlsxir.multi_extract(@path, nil, false, nil, options)

      Enum.each(results, fn
        {:ok, tid} -> on_exit(fn -> Xlsxir.close(tid) end)
        _ -> :ok
      end)

      assert [{:ok, first}, {:ok, second}] = results
      assert Xlsxir.get_info(first, :name) == "Sheet1"
      assert Xlsxir.get_info(second, :name) == "Sheet2"
      assert Xlsxir.get_list(first) == [["A"]]
      assert Xlsxir.get_list(second) == [["A"], ["B"]]
      assert Enum.to_list(Xlsxir.stream_list(@path, 0, options)) == [["A"]]
      assert Enum.to_list(Xlsxir.stream_list(@path, 1, options)) == [["A"], ["B"]]
    end
  end
end
