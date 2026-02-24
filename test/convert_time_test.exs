defmodule ConvertTimeTest do
  use ExUnit.Case
  doctest Xlsxir.ConvertDateTime

  import Xlsxir.ConvertDateTime

  @test_data %{~c"0.0" => {0, 0 , 0},
               ~c"0.25" => {6, 0, 0},
               ~c"0.5" => {12, 0, 0},
               ~c"0.29166666666666669" => {7, 0, 0},
               ~c"0.64583333333333337" => {15, 30, 0},
               ~c"0.754"=> {18, 5, 45}}


  test "converts fractions to the appropriate numbers" do
    for {input, expected} <- @test_data do
      assert from_charlist(input) == expected
    end
  end

  test "accepts a single 0 as a valid float value" do
    assert from_charlist(~c"0") == {0, 0, 0}
  end
end
