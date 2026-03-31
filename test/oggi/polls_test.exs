defmodule Oggi.PollsTest do
  use Oggi.DataCase

  alias Oggi.Polls

  describe "create_poll/1" do
    test "creates a poll with slots and organizer as participant" do
      attrs = %{
        title: "Team sync",
        meeting_duration: 60,
        date_range_start: ~D[2026-04-06],
        date_range_end: ~D[2026-04-06],
        organizer_name: "Alice",
        patterns: [%{kind: :morning, days_of_week: []}]
      }

      assert {:ok, poll} = Polls.create_poll(attrs)
      assert poll.title == "Team sync"
      assert poll.meeting_duration == 60
      assert poll.status == :open
      assert poll.admin_token != nil
      assert poll.participant_token != nil
      assert poll.admin_token != poll.participant_token
    end

    test "generates slots from patterns" do
      attrs = %{
        title: "Test",
        meeting_duration: 60,
        date_range_start: ~D[2026-04-06],
        date_range_end: ~D[2026-04-06],
        organizer_name: "Alice",
        patterns: [%{kind: :morning, days_of_week: []}]
      }

      {:ok, poll} = Polls.create_poll(attrs)
      poll = Polls.get_poll!(poll.id)

      assert length(poll.slots) == 4
    end

    test "auto-joins organizer as participant" do
      attrs = %{
        title: "Test",
        meeting_duration: 60,
        date_range_start: ~D[2026-04-06],
        date_range_end: ~D[2026-04-06],
        organizer_name: "Alice",
        patterns: [%{kind: :morning, days_of_week: []}]
      }

      {:ok, poll} = Polls.create_poll(attrs)
      poll = Polls.get_poll!(poll.id)

      assert length(poll.participants) == 1
      [organizer] = poll.participants
      assert organizer.name == "Alice"
      assert organizer.is_organizer == true
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = Polls.create_poll(%{})
      assert changeset.valid? == false
    end
  end

  describe "get_poll_by_token/1" do
    test "finds poll by admin token" do
      {:ok, poll} = create_poll()

      found = Polls.get_poll_by_token(poll.admin_token)

      assert found.id == poll.id
    end

    test "finds poll by participant token" do
      {:ok, poll} = create_poll()

      found = Polls.get_poll_by_token(poll.participant_token)

      assert found.id == poll.id
    end

    test "returns nil for unknown token" do
      assert Polls.get_poll_by_token("nonexistent") == nil
    end
  end

  describe "join_poll/2" do
    test "adds a participant to the poll" do
      {:ok, poll} = create_poll()

      assert {:ok, participant} = Polls.join_poll(poll.id, "Bob")
      assert participant.name == "Bob"
      assert participant.is_organizer == false

      poll = Polls.get_poll!(poll.id)
      assert length(poll.participants) == 2
    end
  end

  describe "toggle_unavailability/2" do
    test "marks a slot as unavailable" do
      {:ok, poll} = create_poll()
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)
      slot = hd(poll.slots)

      assert {:ok, :marked} = Polls.toggle_unavailability(bob.id, slot.id)
    end

    test "unmarks a slot when toggled again" do
      {:ok, poll} = create_poll()
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)
      slot = hd(poll.slots)

      {:ok, :marked} = Polls.toggle_unavailability(bob.id, slot.id)
      assert {:ok, :unmarked} = Polls.toggle_unavailability(bob.id, slot.id)
    end
  end

  describe "close_poll/1" do
    test "resolves to the first fully-available slot" do
      {:ok, poll} = create_poll()
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)

      # Bob can't make the first slot (08:00)
      first_slot = hd(poll.slots)
      Polls.toggle_unavailability(bob.id, first_slot.id)

      assert {:ok, resolved_poll} = Polls.close_poll(poll.id)
      assert resolved_poll.status == :resolved
      # Should pick 09:00, not 08:00
      assert resolved_poll.resolved_slot.start_time.hour == 9
    end

    test "resolves to first slot when nobody is unavailable" do
      {:ok, poll} = create_poll()

      assert {:ok, resolved_poll} = Polls.close_poll(poll.id)
      assert resolved_poll.resolved_slot.start_time.hour == 8
    end

    test "returns no_available_slot when all slots are blocked" do
      {:ok, poll} = create_poll()
      {:ok, bob} = Polls.join_poll(poll.id, "Bob")
      poll = Polls.get_poll!(poll.id)

      # Bob blocks every slot
      for slot <- poll.slots do
        Polls.toggle_unavailability(bob.id, slot.id)
      end

      assert {:ok, resolved_poll} = Polls.close_poll(poll.id)
      assert resolved_poll.status == :closed
      assert resolved_poll.resolved_slot == nil
    end
  end

  # Helper to create a poll with morning slots on a single day
  defp create_poll do
    Polls.create_poll(%{
      title: "Test poll",
      meeting_duration: 60,
      date_range_start: ~D[2026-04-06],
      date_range_end: ~D[2026-04-06],
      organizer_name: "Alice",
      patterns: [%{kind: :morning, days_of_week: []}]
    })
  end
end
