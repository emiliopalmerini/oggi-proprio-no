defmodule Oggi.SlotGenerator do
  @moduledoc """
  Generates concrete time slots from availability patterns within a date range.
  Pure logic, no database.
  """

  @windows %{
    morning: {~T[08:00:00], ~T[12:00:00]},
    afternoon: {~T[12:00:00], ~T[18:00:00]},
    evening: {~T[18:00:00], ~T[22:00:00]}
  }

  def generate(_patterns, {start_date, end_date}, _duration_minutes)
      when start_date > end_date,
      do: []

  def generate(patterns, {start_date, end_date}, duration_minutes) do
    Date.range(start_date, end_date)
    |> Enum.flat_map(fn date ->
      Enum.flat_map(patterns, &generate_slots_for_day(date, &1, duration_minutes))
    end)
    |> Enum.uniq_by(& &1.start_time)
    |> Enum.sort_by(& &1.start_time, NaiveDateTime)
  end

  defp generate_slots_for_day(date, %{days_of_week: []} = pattern, duration_minutes) do
    {window_start, window_end} = window_for(pattern)
    fill_window(date, window_start, window_end, duration_minutes)
  end

  defp generate_slots_for_day(date, pattern, duration_minutes) do
    if (Date.day_of_week(date, :sunday) - 1) in pattern.days_of_week do
      {window_start, window_end} = window_for(pattern)
      fill_window(date, window_start, window_end, duration_minutes)
    else
      []
    end
  end

  defp window_for(%{kind: :custom, custom_start: start_time, custom_end: end_time}) do
    {start_time, end_time}
  end

  defp window_for(%{kind: kind}), do: Map.fetch!(@windows, kind)

  defp fill_window(date, window_start, window_end, duration_minutes) do
    duration_seconds = duration_minutes * 60
    cursor = NaiveDateTime.new!(date, window_start)
    boundary = NaiveDateTime.new!(date, window_end)

    Stream.unfold(cursor, fn current ->
      slot_end = NaiveDateTime.add(current, duration_seconds)

      if NaiveDateTime.compare(slot_end, boundary) in [:lt, :eq] do
        {%{start_time: current, end_time: slot_end}, slot_end}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end
end
