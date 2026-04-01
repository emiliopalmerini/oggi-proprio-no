defmodule Oggi.Polls.Cleaner do
  use GenServer

  import Ecto.Query

  alias Oggi.Repo
  alias Oggi.Polls.{Poll, Slot}

  @interval :timer.hours(24)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Deletes polls that are stale as of `now`:
  - Resolved polls: 7 days after the resolved slot's end_time
  - Closed polls: 7 days after date_range_end
  """
  def delete_stale_polls(now \\ NaiveDateTime.utc_now()) do
    cutoff_date = NaiveDateTime.add(now, -7, :day) |> NaiveDateTime.to_date()

    resolved_ids =
      Poll
      |> where([p], p.status == :resolved)
      |> join(:inner, [p], s in Slot, on: p.resolved_slot_id == s.id)
      |> where([_p, s], fragment("date(?)", s.end_time) <= ^cutoff_date)
      |> select([p], p.id)

    closed_ids =
      Poll
      |> where([p], p.status == :closed)
      |> where([p], p.date_range_end <= ^cutoff_date)
      |> select([p], p.id)

    stale_ids = Repo.all(resolved_ids) ++ Repo.all(closed_ids)

    Poll
    |> where([p], p.id in ^stale_ids)
    |> Repo.delete_all()
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    schedule()
    {:ok, opts}
  end

  @impl true
  def handle_info(:cleanup, opts) do
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now())
    delete_stale_polls(now)
    schedule()
    {:noreply, opts}
  end

  defp schedule do
    Process.send_after(self(), :cleanup, @interval)
  end
end
