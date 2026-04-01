defmodule Oggi.Polls.CleanerTest do
  use Oggi.DataCase

  alias Oggi.Polls
  alias Oggi.Polls.Cleaner

  describe "delete_stale_polls/1" do
    test "deletes resolved poll 7 days after resolved slot end_time" do
      {:ok, poll} = create_poll(~D[2026-03-20], ~D[2026-03-20])
      {:ok, poll} = Polls.close_poll(poll.id)
      assert poll.status == :resolved

      # 6 days after the slot end_time — should keep
      now = ~N[2026-03-26 12:00:00]
      assert {0, _} = Cleaner.delete_stale_polls(now)
      assert Polls.get_poll_by_token(poll.admin_token) != nil

      # 7 days after the slot end_time — should delete
      now = ~N[2026-03-27 12:00:00]
      assert {1, _} = Cleaner.delete_stale_polls(now)
      assert Polls.get_poll_by_token(poll.admin_token) == nil
    end

    test "deletes closed (unresolved) poll 7 days after date_range_end" do
      {:ok, poll} = create_poll(~D[2026-03-20], ~D[2026-03-22])

      # Block all slots so it closes without resolving
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)
      for slot <- poll.slots, do: Polls.toggle_unavailability(bob.id, slot.id)

      {:ok, poll} = Polls.close_poll(poll.id)
      assert poll.status == :closed

      # 6 days after date_range_end — should keep
      now = ~N[2026-03-28 23:59:59]
      assert {0, _} = Cleaner.delete_stale_polls(now)
      assert Polls.get_poll_by_token(poll.admin_token) != nil

      # 7 days after date_range_end — should delete
      now = ~N[2026-03-29 00:00:00]
      assert {1, _} = Cleaner.delete_stale_polls(now)
      assert Polls.get_poll_by_token(poll.admin_token) == nil
    end

    test "does not delete open polls" do
      {:ok, poll} = create_poll(~D[2026-03-01], ~D[2026-03-01])
      assert poll.status == :open

      now = ~N[2026-04-01 00:00:00]
      assert {0, _} = Cleaner.delete_stale_polls(now)
      assert Polls.get_poll_by_token(poll.admin_token) != nil
    end

    test "deletes multiple stale polls at once" do
      {:ok, poll1} = create_poll(~D[2026-03-10], ~D[2026-03-10])
      {:ok, _} = Polls.close_poll(poll1.id)

      {:ok, poll2} = create_poll(~D[2026-03-12], ~D[2026-03-12])
      {:ok, _} = Polls.close_poll(poll2.id)

      now = ~N[2026-03-20 00:00:00]
      assert {2, _} = Cleaner.delete_stale_polls(now)
    end

    test "cascade deletes slots, participants, and unavailabilities" do
      {:ok, poll} = create_poll(~D[2026-03-20], ~D[2026-03-20])
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)
      slot = hd(poll.slots)
      Polls.toggle_unavailability(bob.id, slot.id)

      {:ok, _} = Polls.close_poll(poll.id)

      now = ~N[2026-03-28 00:00:00]
      assert {1, _} = Cleaner.delete_stale_polls(now)

      # Verify related records are gone
      assert Oggi.Repo.all(Oggi.Polls.Slot) == []
      assert Oggi.Repo.all(Oggi.Polls.Participant) == []
      assert Oggi.Repo.all(Oggi.Polls.Unavailability) == []
    end
  end

  describe "GenServer scheduling" do
    test "runs cleanup on :cleanup message" do
      {:ok, poll} = create_poll(~D[2026-03-10], ~D[2026-03-10])
      {:ok, _} = Polls.close_poll(poll.id)

      # Send cleanup to the already-running supervised Cleaner
      send(Cleaner, :cleanup)

      # Wait for it to process
      :sys.get_state(Cleaner)

      assert Polls.get_poll_by_token(poll.admin_token) == nil
    end
  end

  defp create_poll(date_start, date_end) do
    Polls.create_poll(%{
      title: "Test poll",
      meeting_duration: 60,
      date_range_start: date_start,
      date_range_end: date_end,
      organizer_name: "Alice",
      patterns: [%{kind: :morning, days_of_week: []}]
    })
  end
end
