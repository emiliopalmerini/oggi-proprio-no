defmodule Oggi.SlotGeneratorTest do
  use ExUnit.Case

  alias Oggi.SlotGenerator

  describe "generate/3" do
    test "generates morning slots (08-12) with 1h duration" do
      patterns = [%{kind: :morning, days_of_week: []}]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      assert length(slots) == 4
      assert Enum.at(slots, 0).start_time == ~N[2026-04-06 08:00:00]
      assert Enum.at(slots, 0).end_time == ~N[2026-04-06 09:00:00]
      assert Enum.at(slots, 1).start_time == ~N[2026-04-06 09:00:00]
      assert Enum.at(slots, 2).start_time == ~N[2026-04-06 10:00:00]
      assert Enum.at(slots, 3).start_time == ~N[2026-04-06 11:00:00]
    end

    test "generates afternoon slots (12-18) with 2h duration" do
      patterns = [%{kind: :afternoon, days_of_week: []}]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 120)

      assert length(slots) == 3
      assert Enum.at(slots, 0).start_time == ~N[2026-04-06 12:00:00]
      assert Enum.at(slots, 1).start_time == ~N[2026-04-06 14:00:00]
      assert Enum.at(slots, 2).start_time == ~N[2026-04-06 16:00:00]
    end

    test "generates evening slots (18-22)" do
      patterns = [%{kind: :evening, days_of_week: []}]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      assert length(slots) == 4
      assert Enum.at(slots, 0).start_time == ~N[2026-04-06 18:00:00]
      assert Enum.at(slots, 3).start_time == ~N[2026-04-06 21:00:00]
    end

    test "generates custom window slots" do
      patterns = [%{kind: :custom, days_of_week: [], custom_start: ~T[14:00:00], custom_end: ~T[18:00:00]}]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      assert length(slots) == 4
      assert Enum.at(slots, 0).start_time == ~N[2026-04-06 14:00:00]
      assert Enum.at(slots, 3).start_time == ~N[2026-04-06 17:00:00]
    end

    test "filters by days_of_week" do
      # 2026-04-06 is a Monday (1), 2026-04-07 is Tuesday (2)
      patterns = [%{kind: :morning, days_of_week: [1]}]
      date_range = {~D[2026-04-06], ~D[2026-04-07]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      # Only Monday slots, not Tuesday
      assert length(slots) == 4
      assert Enum.all?(slots, &(&1.start_time.day == 6))
    end

    test "spans multiple days" do
      patterns = [%{kind: :morning, days_of_week: []}]
      date_range = {~D[2026-04-06], ~D[2026-04-08]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      assert length(slots) == 12  # 3 days * 4 slots
    end

    test "deduplicates overlapping patterns" do
      # Two patterns that overlap: morning (08-12) and custom 09-11
      patterns = [
        %{kind: :morning, days_of_week: []},
        %{kind: :custom, days_of_week: [], custom_start: ~T[09:00:00], custom_end: ~T[11:00:00]}
      ]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      # 08, 09, 10, 11 from morning + 09, 10 from custom = 4 unique
      assert length(slots) == 4
    end

    test "returns empty list when duration exceeds window" do
      patterns = [%{kind: :morning, days_of_week: []}]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 300)

      assert slots == []
    end

    test "returns empty list for empty date range" do
      patterns = [%{kind: :morning, days_of_week: []}]
      date_range = {~D[2026-04-08], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      assert slots == []
    end

    test "slots are sorted by start_time" do
      patterns = [
        %{kind: :evening, days_of_week: []},
        %{kind: :morning, days_of_week: []}
      ]
      date_range = {~D[2026-04-06], ~D[2026-04-06]}

      slots = SlotGenerator.generate(patterns, date_range, 60)

      start_times = Enum.map(slots, & &1.start_time)
      assert start_times == Enum.sort(start_times, NaiveDateTime)
    end
  end
end
