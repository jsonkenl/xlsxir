defmodule ConvertDateTest do
  use ExUnit.Case
  doctest Xlsxir.ConvertDate

  import Xlsxir.ConvertDate

  def test_one_data(),
    do: [
      ~c"42005",
      ~c"42036",
      ~c"42064",
      ~c"42095",
      ~c"42125",
      ~c"42156",
      ~c"42186",
      ~c"42217",
      ~c"42248",
      ~c"42278",
      ~c"42309",
      ~c"42339"
    ]

  def test_one_results() do
    [
      {2015, 1, 1},
      {2015, 2, 1},
      {2015, 3, 1},
      {2015, 4, 1},
      {2015, 5, 1},
      {2015, 6, 1},
      {2015, 7, 1},
      {2015, 8, 1},
      {2015, 9, 1},
      {2015, 10, 1},
      {2015, 11, 1},
      {2015, 12, 1}
    ]
  end

  test "first day of every month in non-leap year (2015)" do
    assert Enum.map(test_one_data(), &from_serial/1) == test_one_results()
  end

  def test_two_data(),
    do: [
      ~c"42035",
      ~c"42063",
      ~c"42094",
      ~c"42124",
      ~c"42155",
      ~c"42185",
      ~c"42216",
      ~c"42247",
      ~c"42277",
      ~c"42308",
      ~c"42338",
      ~c"42369",
      ~c"44530"
    ]

  def test_two_results() do
    [
      {2015, 1, 31},
      {2015, 2, 28},
      {2015, 3, 31},
      {2015, 4, 30},
      {2015, 5, 31},
      {2015, 6, 30},
      {2015, 7, 31},
      {2015, 8, 31},
      {2015, 9, 30},
      {2015, 10, 31},
      {2015, 11, 30},
      {2015, 12, 31},
      {2021, 11, 30}
    ]
  end

  test "last day of every month in non-leap year (2015, 2021)" do
    assert Enum.map(test_two_data(), &from_serial/1) == test_two_results()
  end

  def test_three_data(),
    do: [
      ~c"42019",
      ~c"42050",
      ~c"42078",
      ~c"42109",
      ~c"42139",
      ~c"42170",
      ~c"42200",
      ~c"42231",
      ~c"42262",
      ~c"42292",
      ~c"42323",
      ~c"42353"
    ]

  def test_three_results() do
    [
      {2015, 1, 15},
      {2015, 2, 15},
      {2015, 3, 15},
      {2015, 4, 15},
      {2015, 5, 15},
      {2015, 6, 15},
      {2015, 7, 15},
      {2015, 8, 15},
      {2015, 9, 15},
      {2015, 10, 15},
      {2015, 11, 15},
      {2015, 12, 15}
    ]
  end

  test "middle of every month in non-leap year (2015)" do
    assert Enum.map(test_three_data(), &from_serial/1) == test_three_results()
  end

  def test_four_data(),
    do: [
      ~c"42370",
      ~c"42401",
      ~c"42430",
      ~c"42461",
      ~c"42491",
      ~c"42522",
      ~c"42552",
      ~c"42583",
      ~c"42614",
      ~c"42644",
      ~c"42675",
      ~c"42705"
    ]

  def test_four_results() do
    [
      {2016, 1, 1},
      {2016, 2, 1},
      {2016, 3, 1},
      {2016, 4, 1},
      {2016, 5, 1},
      {2016, 6, 1},
      {2016, 7, 1},
      {2016, 8, 1},
      {2016, 9, 1},
      {2016, 10, 1},
      {2016, 11, 1},
      {2016, 12, 1}
    ]
  end

  test "first day of every month in leap year (2016)" do
    assert Enum.map(test_four_data(), &from_serial/1) == test_four_results()
  end

  def test_five_data(),
    do: [
      ~c"42400",
      ~c"42429",
      ~c"42460",
      ~c"42490",
      ~c"42521",
      ~c"42551",
      ~c"42582",
      ~c"42613",
      ~c"42643",
      ~c"42674",
      ~c"42704",
      ~c"42735"
    ]

  def test_five_results() do
    [
      {2016, 1, 31},
      {2016, 2, 29},
      {2016, 3, 31},
      {2016, 4, 30},
      {2016, 5, 31},
      {2016, 6, 30},
      {2016, 7, 31},
      {2016, 8, 31},
      {2016, 9, 30},
      {2016, 10, 31},
      {2016, 11, 30},
      {2016, 12, 31}
    ]
  end

  test "last day of every month in leap year (2016)" do
    assert Enum.map(test_five_data(), &from_serial/1) == test_five_results()
  end

  def test_six_data(),
    do: [
      ~c"42384",
      ~c"42415",
      ~c"42444",
      ~c"42475",
      ~c"42505",
      ~c"42536",
      ~c"42566",
      ~c"42597",
      ~c"42628",
      ~c"42658",
      ~c"42689",
      ~c"42719"
    ]

  def test_six_results() do
    [
      {2016, 1, 15},
      {2016, 2, 15},
      {2016, 3, 15},
      {2016, 4, 15},
      {2016, 5, 15},
      {2016, 6, 15},
      {2016, 7, 15},
      {2016, 8, 15},
      {2016, 9, 15},
      {2016, 10, 15},
      {2016, 11, 15},
      {2016, 12, 15}
    ]
  end

  test "middle of every month in leap year (2016)" do
    assert Enum.map(test_six_data(), &from_serial/1) == test_six_results()
  end
end
