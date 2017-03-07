defmodule Xlsxir.ConvertDateTime do
  @moduledoc """
  Converts a datetime formatted as a decimal number that represents the fraction
  of the day in `char_list` form, to an elixir naive datetime
  """

  @doc """
  Given a charlist in the form of a serial date float representing fraction of the day
  return a naive datetime

  ## Parameters

  - `charlist` - Character list in the form of a date serial with a fractional number (i.e. `41261.6013888889`)

  ## Example

      iex> Xlsxir.ConvertDateTime.from_charlist('41261.6013888889')
      ~N[2012-12-18 14:26:00]
  """
  def from_charlist('0'), do: {0, 0, 0}
  def from_charlist(charlist) do
    charlist
    |> List.to_float
    |> from_float
  end

  def from_float(n) when is_float(n) do
    n = if n > 59, do: n - 1, else: n # Lotus bug
    convert_from_serial(n)
  end

  defp convert_from_serial(time) when is_float(time) and time >= 0 and time < 1.0 do
    {hours, min_fraction} = split_float(time * 24)
    {minutes, sec_fraction} = split_float(min_fraction * 60)
    {seconds, _} = split_float(sec_fraction * 60)

    {hours, minutes, seconds}
  end
  defp convert_from_serial(n) when is_float(n) do
    {whole_days, fractional_day} = split_float(n)
    {hrs, mins, secs} = convert_from_serial(fractional_day)
    {{1899, 12, 31}, {0, 0, 0}}
    |> Timex.to_naive_datetime
    |> Timex.shift(days: whole_days)
    |> Timex.shift(hours: hrs)
    |> Timex.shift(minutes: mins)
    |> Timex.shift(seconds: secs)
    |> Timex.to_naive_datetime
  end

  defp split_float(f) do
    whole = f
      |> Float.floor
      |> round
    {whole, f - whole}
  end
end