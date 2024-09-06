defmodule Xlsxir.ConvertDate do
  @moduledoc """
  Converts an ISO 8601 date format serial number, in `char_list` format, to a date formatted in
  Erlang `:calendar.date()` type format (i.e. `{year, month, day}`).
  """

  @doc """
  Receives an ISO 8601 date format serial number and returns a date formatted in Erlang `:calendar.date()`
  type format.

  ## Parameters

  - `serial` - ISO 8601 date format serial in `char_list` format (i.e. 4/30/75 as '27514')

  ## Example

      iex> Xlsxir.ConvertDate.from_serial('27514')
      {1975, 4, 30}
  """
  def from_serial(serial) do
    f_serial = serial
               |> convert_char_number
               |> is_float
               |> case do
                    false -> List.to_integer(serial)
                    true  -> serial
                             |> List.to_float()
                             |> Float.floor
                             |> round
                  end

    # Convert to gregorian days and get date from that
    gregorian = f_serial - 2 +               # adjust two days for first and last day since base year
                date_to_days({1900, 1, 1})   # Add days in base year 1900

    gregorian
    |> days_to_date
  end

  defp date_to_days(date), do: :calendar.date_to_gregorian_days(date)

  defp days_to_date(days) do
    case Application.get_env(:xlsxir, :date_system, :elixir) do
      :elixir -> :calendar.gregorian_days_to_date(days) |> Date.from_erl!()
      :erlang -> :calendar.gregorian_days_to_date(days)
    end
  end

  @doc """
  Converts extracted number in `char_list` format to either `integer` or `float`.
  """
  def convert_char_number(number) do
    str = List.to_string(number)

    str
    |> String.match?(~r/[.eE]/)
    |> case do
         false -> List.to_integer(number)
         true  -> case Float.parse(str) do
                    {f, _} -> f
                        _  -> raise "Invalid Float"
                  end
       end
  end
end
