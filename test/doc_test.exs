defmodule DocTest do
  use ExUnit.Case
  doctest Xlsxir
  doctest Xlsxir.Unzip
  doctest Xlsxir.ConvertDate
  doctest Xlsxir.SaxParser
  doctest Xlsxir.XlsxFile
end
