defmodule Oggi.Polls do
  import Ecto.Query

  alias Oggi.Repo
  alias Oggi.Polls.{Poll, Slot, Participant, Unavailability}
  alias Oggi.SlotGenerator

  def create_poll(attrs) do
    patterns = Map.get(attrs, :patterns, [])
    organizer_name = Map.get(attrs, :organizer_name)

    changeset = Poll.changeset(%Poll{}, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:poll, changeset)
    |> Ecto.Multi.run(:slots, fn _repo, %{poll: poll} ->
      insert_slots(poll, patterns)
    end)
    |> Ecto.Multi.run(:organizer, fn _repo, %{poll: poll} ->
      insert_organizer(poll, organizer_name)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{poll: poll}} -> {:ok, poll}
      {:error, :poll, changeset, _} -> {:error, changeset}
    end
  end

  def get_poll!(id) do
    Poll
    |> Repo.get!(id)
    |> Repo.preload([:slots, :resolved_slot, participants: :unavailabilities])
  end

  def get_poll_by_token(token) do
    Poll
    |> where([p], p.admin_token == ^token or p.participant_token == ^token)
    |> Repo.one()
    |> case do
      nil -> nil
      poll -> Repo.preload(poll, [:slots, :resolved_slot, participants: :unavailabilities])
    end
  end

  def join_poll(poll_id, name) do
    %Participant{poll_id: poll_id}
    |> Participant.changeset(%{name: name, is_organizer: false})
    |> Repo.insert()
  end

  def toggle_unavailability(participant_id, slot_id) do
    case Repo.get_by(Unavailability, participant_id: participant_id, slot_id: slot_id) do
      nil ->
        %Unavailability{participant_id: participant_id, slot_id: slot_id}
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, :marked}
          error -> error
        end

      _existing ->
        Unavailability
        |> where([u], u.participant_id == ^participant_id and u.slot_id == ^slot_id)
        |> Repo.delete_all()
        |> case do
          {1, _} -> {:ok, :unmarked}
          error -> {:error, error}
        end
    end
  end

  def close_poll(poll_id) do
    poll = get_poll!(poll_id)
    resolved_slot = find_first_available_slot(poll)

    status = if resolved_slot, do: :resolved, else: :closed

    poll
    |> Ecto.Changeset.change(%{status: status, resolved_slot_id: slot_id(resolved_slot)})
    |> Repo.update()
    |> case do
      {:ok, poll} ->
        {:ok,
         Repo.preload(poll, [:resolved_slot, :slots, participants: :unavailabilities],
           force: true
         )}

      error ->
        error
    end
  end

  defp slot_id(nil), do: nil
  defp slot_id(slot), do: slot.id

  defp find_first_available_slot(poll) do
    unavailable_slot_ids =
      poll.participants
      |> Enum.flat_map(& &1.unavailabilities)
      |> MapSet.new(& &1.slot_id)

    poll.slots
    |> Enum.sort_by(& &1.start_time, NaiveDateTime)
    |> Enum.find(fn slot -> slot.id not in unavailable_slot_ids end)
  end

  defp insert_slots(poll, patterns) do
    date_range = {poll.date_range_start, poll.date_range_end}

    slots =
      SlotGenerator.generate(patterns, date_range, poll.meeting_duration)
      |> Enum.map(fn slot_attrs ->
        %Slot{poll_id: poll.id, start_time: slot_attrs.start_time, end_time: slot_attrs.end_time}
      end)
      |> Enum.map(&Repo.insert!/1)

    {:ok, slots}
  end

  defp insert_organizer(poll, name) do
    %Participant{poll_id: poll.id}
    |> Participant.changeset(%{name: name, is_organizer: true})
    |> Repo.insert()
  end
end
