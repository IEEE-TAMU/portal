defmodule IeeeTamuPortalWeb.TimezoneHelper do
  @moduledoc """
  Shared timezone conversion helpers for formatting datetimes in the user's local timezone.
  """

  @doc """
  Formats a datetime in the given timezone using a `Calendar.strftime/2` pattern.

  Handles `DateTime`, `NaiveDateTime`, and `nil`.
  """
  def format_local(nil, _tz, _pattern), do: ""

  def format_local(%DateTime{} = dt, tz, pattern) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, local} -> Calendar.strftime(local, pattern)
      _ -> Calendar.strftime(dt, pattern)
    end
  end

  def format_local(%NaiveDateTime{} = naive, tz, pattern) do
    case DateTime.from_naive(naive, "Etc/UTC") do
      {:ok, dt} -> format_local(dt, tz, pattern)
      _ -> Calendar.strftime(naive, pattern)
    end
  end

  @doc """
  Converts a `DateTime` to a naive-local string suitable for `datetime-local` HTML inputs.

  Returns `nil` if the input is `nil`.
  """
  def to_local_naive_input(nil, _tz), do: nil

  def to_local_naive_input(%DateTime{} = dt, tz) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, local} ->
        local
        |> DateTime.to_naive()
        |> naive_to_input_string()

      _ ->
        nil
    end
  end

  defp naive_to_input_string(%NaiveDateTime{} = naive) do
    NaiveDateTime.to_iso8601(naive) |> String.slice(0, 16)
  end
end
