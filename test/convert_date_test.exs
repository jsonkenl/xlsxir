defmodule ConvertDateTest do
  use ExUnit.Case
  doctest Xlsxir.ConvertDate

  import Xlsxir.ConvertDate

  def test_one_data(),
    do: [
      '42005',
      '42036',
      '42064',
      '42095',
      '42125',
      '42156',
      '42186',
      '42217',
      '42248',
      '42278',
      '42309',
      '42339'
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
      '42035',
      '42063',
      '42094',
      '42124',
      '42155',
      '42185',
      '42216',
      '42247',
      '42277',
      '42308',
      '42338',
      '42369',
      '44530'
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
      '42019',
      '42050',
      '42078',
      '42109',
      '42139',
      '42170',
      '42200',
      '42231',
      '42262',
      '42292',
      '42323',
      '42353'
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
      '42370',
      '42401',
      '42430',
      '42461',
      '42491',
      '42522',
      '42552',
      '42583',
      '42614',
      '42644',
      '42675',
      '42705'
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
      '42400',
      '42429',
      '42460',
      '42490',
      '42521',
      '42551',
      '42582',
      '42613',
      '42643',
      '42674',
      '42704',
      '42735'
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
      '42384',
      '42415',
      '42444',
      '42475',
      '42505',
      '42536',
      '42566',
      '42597',
      '42628',
      '42658',
      '42689',
      '42719'
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
