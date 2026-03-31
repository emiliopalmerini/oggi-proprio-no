defmodule OggiWeb.PollLive.Show do
  use OggiWeb, :live_view

  alias Oggi.Polls

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    poll = Polls.get_poll_by_token(token)

    case poll do
      nil ->
        {:ok, push_navigate(socket, to: "/") |> put_flash(:error, "Poll not found")}

      poll ->
        role = if poll.admin_token == token, do: :admin, else: :participant
        participant = find_participant(poll, role)

        if connected?(socket), do: Phoenix.PubSub.subscribe(Oggi.PubSub, "poll:#{poll.id}")

        {:ok,
         assign(socket,
           poll: poll,
           token: token,
           role: role,
           participant: participant,
           join_form: to_form(%{"name" => ""}, as: :participant)
         )}
    end
  end

  @impl true
  def handle_event("join", %{"participant" => %{"name" => name}}, socket) do
    case Polls.join_poll(socket.assigns.poll.id, name) do
      {:ok, participant} ->
        poll = Polls.get_poll!(socket.assigns.poll.id)
        broadcast(poll.id, :poll_updated)
        {:noreply, assign(socket, participant: refresh_participant(poll, participant.id), poll: poll)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not join")}
    end
  end

  @impl true
  def handle_event("toggle_slot", %{"slot-id" => slot_id}, socket) do
    case Polls.toggle_unavailability(socket.assigns.participant.id, slot_id) do
      {:ok, _} ->
        {poll, participant} = refresh_poll_and_participant(socket)
        broadcast(poll.id, :poll_updated)
        {:noreply, assign(socket, poll: poll, participant: participant)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update")}
    end
  end

  @impl true
  def handle_event("close_poll", _params, socket) do
    case Polls.close_poll(socket.assigns.poll.id) do
      {:ok, poll} ->
        broadcast(poll.id, :poll_updated)
        {:noreply, assign(socket, poll: poll)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not close poll")}
    end
  end

  @impl true
  def handle_info(:poll_updated, socket) do
    {poll, participant} = refresh_poll_and_participant(socket)
    {:noreply, assign(socket, poll: poll, participant: participant)}
  end

  defp broadcast(poll_id, message) do
    Phoenix.PubSub.broadcast(Oggi.PubSub, "poll:#{poll_id}", message)
  end

  defp refresh_poll_and_participant(socket) do
    poll = Polls.get_poll!(socket.assigns.poll.id)

    participant =
      case socket.assigns.participant do
        nil -> nil
        p -> refresh_participant(poll, p.id)
      end

    {poll, participant}
  end

  defp refresh_participant(poll, participant_id) do
    Enum.find(poll.participants, &(&1.id == participant_id))
  end

  defp find_participant(poll, :admin) do
    Enum.find(poll.participants, & &1.is_organizer)
  end

  defp find_participant(_poll, :participant), do: nil

  defp slot_unavailable?(_slot, nil), do: false

  defp slot_unavailable?(slot, participant) do
    Enum.any?(participant.unavailabilities, &(&1.slot_id == slot.id))
  end

  defp unavailability_count(slot, poll) do
    poll.participants
    |> Enum.flat_map(& &1.unavailabilities)
    |> Enum.count(&(&1.slot_id == slot.id))
  end

  defp format_time(naive_datetime) do
    Calendar.strftime(naive_datetime, "%H:%M")
  end

  defp format_date(naive_datetime) do
    Calendar.strftime(naive_datetime, "%a %b %d")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto mt-10">
      <h1 class="text-2xl font-bold mb-2">{@poll.title}</h1>
      <p :if={@poll.description} class="text-gray-600 mb-4">{@poll.description}</p>

      <%!-- Admin: show participant link --%>
      <div :if={@role == :admin} class="mb-6 p-3 bg-gray-50 rounded">
        <p class="text-sm text-gray-500">Share this link with participants:</p>
        <a href={"/p/#{@poll.participant_token}"} id="participant-link" class="text-blue-600 underline text-sm">
          /p/{@poll.participant_token}
        </a>
      </div>

      <%!-- Join form for participants who haven't joined yet --%>
      <div :if={@role == :participant && is_nil(@participant) && @poll.status == :open} class="mb-6">
        <.form for={@join_form} id="join-form" phx-submit="join" class="flex gap-2">
          <.input field={@join_form[:name]} placeholder="Your name" />
          <.button type="submit">Join</.button>
        </.form>
      </div>

      <%!-- Resolved state --%>
      <div :if={@poll.status in [:resolved, :closed]} class="mb-6 p-4 rounded bg-green-50">
        <p :if={@poll.status == :resolved} class="font-semibold text-green-800">
          resolved — {format_date(@poll.resolved_slot.start_time)} {format_time(@poll.resolved_slot.start_time)}-{format_time(@poll.resolved_slot.end_time)}
        </p>
        <p :if={@poll.status == :closed} class="font-semibold text-red-800">
          No available slot found.
        </p>
      </div>

      <%!-- Slot grid --%>
      <div class="space-y-2">
        <div
          :for={slot <- Enum.sort_by(@poll.slots, & &1.start_time, NaiveDateTime)}
          id={"slot-#{slot.id}"}
          phx-click={if @participant && @poll.status == :open, do: "toggle_slot"}
          phx-value-slot-id={slot.id}
          class={[
            "p-3 rounded border flex justify-between items-center",
            if(@participant && @poll.status == :open, do: "cursor-pointer hover:bg-gray-50", else: ""),
            if(slot_unavailable?(slot, @participant), do: "unavailable bg-red-50 border-red-300", else: "bg-white")
          ]}
        >
          <span class="font-mono">
            {format_date(slot.start_time)} {format_time(slot.start_time)}-{format_time(slot.end_time)}
          </span>
          <span :if={@role == :admin} class="text-sm text-gray-500">
            {unavailability_count(slot, @poll)} unavailable
          </span>
        </div>
      </div>

      <%!-- Close button for admin --%>
      <button
        :if={@role == :admin && @poll.status == :open}
        id="close-poll"
        phx-click="close_poll"
        class="mt-6 w-full bg-red-600 text-white py-2 px-4 rounded hover:bg-red-700"
      >
        Close poll & find best slot
      </button>
    </div>
    """
  end
end
