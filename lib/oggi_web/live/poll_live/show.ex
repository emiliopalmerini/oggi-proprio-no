defmodule OggiWeb.PollLive.Show do
  use OggiWeb, :live_view

  alias Oggi.Polls

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    poll = Polls.get_poll_by_token(token)

    case poll do
      nil ->
        {:ok, push_navigate(socket, to: "/") |> put_flash(:error, gettext("Poll not found"))}

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

        {:noreply,
         assign(socket, participant: refresh_participant(poll, participant.id), poll: poll)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not join"))}
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
        {:noreply, put_flash(socket, :error, gettext("Could not update"))}
    end
  end

  @impl true
  def handle_event("close_poll", _params, socket) do
    case Polls.close_poll(socket.assigns.poll.id) do
      {:ok, poll} ->
        broadcast(poll.id, :poll_updated)
        {:noreply, assign(socket, poll: poll)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not close poll"))}
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

  defp slot_days(slots) do
    slots
    |> Enum.map(&NaiveDateTime.to_date(&1.start_time))
    |> Enum.uniq()
    |> Enum.sort(Date)
  end

  defp slot_times(slots) do
    slots
    |> Enum.map(&NaiveDateTime.to_time(&1.start_time))
    |> Enum.uniq()
    |> Enum.sort(Time)
  end

  defp find_slot(slots, day, time) do
    Enum.find(slots, fn slot ->
      NaiveDateTime.to_date(slot.start_time) == day &&
        NaiveDateTime.to_time(slot.start_time) == time
    end)
  end

  defp format_time(naive_datetime) do
    Calendar.strftime(naive_datetime, "%H:%M")
  end

  defp format_date_long(naive_datetime) do
    Calendar.strftime(naive_datetime, "%d/%m/%Y")
  end

  defp organizer_name(poll) do
    case Enum.find(poll.participants, & &1.is_organizer) do
      nil -> gettext("someone")
      p -> p.name
    end
  end

  defp show_calendar?(assigns) do
    assigns.role == :admin or assigns.participant != nil
  end

  defp format_date_range(poll) do
    if poll.date_range_start == poll.date_range_end do
      Calendar.strftime(poll.date_range_start, "%d/%m/%Y")
    else
      Calendar.strftime(poll.date_range_start, "%d/%m/%Y") <>
        " – " <> Calendar.strftime(poll.date_range_end, "%d/%m/%Y")
    end
  end

  defp slot_cell_class(slot, participant, poll) do
    cond do
      poll.status == :resolved && poll.resolved_slot_id == slot.id ->
        "bg-success/15 cursor-default"

      slot_unavailable?(slot, participant) ->
        "bg-error/20 cursor-pointer hover:bg-error/30 active:scale-95"

      participant != nil && poll.status == :open ->
        "bg-base-100 cursor-pointer hover:bg-base-200 active:scale-95"

      true ->
        "bg-base-100"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Poll header --%>
      <div class="mb-6">
        <h1 class="text-2xl font-extrabold tracking-tight">{@poll.title}</h1>
        <p class="text-sm text-base-content/50 mt-0.5">
          {gettext("%{duration} min / organized by %{name}",
            duration: @poll.meeting_duration,
            name: organizer_name(@poll)
          )}
        </p>
      </div>

      <%!-- Admin: share link card --%>
      <div
        :if={@role == :admin && @poll.status == :open}
        class="mb-6 p-4 bg-base-200 rounded-box"
      >
        <p class="text-sm font-medium mb-1.5">{gettext("Share this with participants:")}</p>
        <div class="flex items-center gap-2">
          <code
            id="participant-link"
            class="flex-1 text-sm bg-base-100 px-3 py-2 rounded-field truncate select-all"
          >
            {url(~p"/p/#{@poll.participant_token}")}
          </code>
          <a href={"/p/#{@poll.participant_token}"} class="hidden">link</a>
          <button
            phx-click={JS.dispatch("phx:copy", to: "#participant-link")}
            class="btn btn-sm btn-primary btn-soft"
          >
            <.icon name="hero-clipboard-document" class="size-4" />
            {gettext("Copy")}
          </button>
        </div>
      </div>

      <%!-- Participant landing page (not yet joined, poll open) --%>
      <div
        :if={@role == :participant && is_nil(@participant) && @poll.status == :open}
        class="mb-6 p-8 bg-base-200 rounded-box text-center max-w-md mx-auto"
      >
        <.icon name="hero-calendar-days" class="size-10 text-primary mx-auto mb-3" />
        <p class="text-lg font-bold mb-1">{gettext("You've been invited!")}</p>
        <p class="text-sm text-base-content/60 mb-4">
          {gettext("%{organizer} is looking for the best time for:", organizer: organizer_name(@poll))}
        </p>
        <p class="font-semibold text-primary mb-4">{@poll.title}</p>

        <div class="flex flex-col gap-1 text-sm text-base-content/60 mb-6">
          <p>
            <.icon name="hero-clock" class="size-4 inline-block align-text-bottom" />
            {gettext("%{duration} minutes", duration: @poll.meeting_duration)}
          </p>
          <p>
            <.icon name="hero-calendar" class="size-4 inline-block align-text-bottom" />
            {format_date_range(@poll)}
          </p>
          <p>
            <.icon name="hero-users" class="size-4 inline-block align-text-bottom" />
            {gettext("%{count} participants so far", count: length(@poll.participants))}
          </p>
        </div>

        <div class="bg-base-300/50 rounded-box p-4 mb-6 text-sm text-base-content/70">
          <p class="font-medium mb-1">{gettext("How does it work?")}</p>
          <p>
            {gettext(
              "Enter your name, then mark the slots when you are NOT available. The app will find the best time for everyone."
            )}
          </p>
        </div>

        <.form for={@join_form} id="join-form" phx-submit="join" class="flex gap-2 max-w-xs mx-auto">
          <.input field={@join_form[:name]} placeholder={gettext("Your name")} />
          <.button type="submit">{gettext("Join")}</.button>
        </.form>
      </div>

      <%!-- Resolved / closed banner --%>
      <div
        :if={@poll.status == :resolved}
        class="mb-6 p-4 bg-success/10 border border-success/30 rounded-box"
      >
        <div class="flex items-center gap-2">
          <.icon name="hero-check-circle-solid" class="size-6 text-success" />
          <div>
            <p class="font-bold text-success">{gettext("We have a winner!")}</p>
            <p class="text-sm">
              {gettext("%{date} — %{start} to %{end}",
                date: format_date_long(@poll.resolved_slot.start_time),
                start: format_time(@poll.resolved_slot.start_time),
                end: format_time(@poll.resolved_slot.end_time)
              )}
            </p>
          </div>
        </div>
      </div>

      <div
        :if={@poll.status == :closed && is_nil(@poll.resolved_slot_id)}
        class="mb-6 p-4 bg-error/10 border border-error/30 rounded-box"
      >
        <div class="flex items-center gap-2">
          <.icon name="hero-x-circle-solid" class="size-6 text-error" />
          <p class="font-bold text-error">{gettext("No available slot found. Oggi proprio no!")}</p>
        </div>
      </div>

      <%!-- Everything below is only visible after joining (or for admin) --%>
      <%= if show_calendar?(assigns) do %>
        <%!-- Participant instruction --%>
        <p
          :if={@participant && @poll.status == :open}
          class="mb-3 text-sm text-base-content/60"
        >
          {raw(gettext("Tap the slots when you <strong>can't</strong> make it. Red = you are busy."))}
        </p>

        <%!-- Calendar grid --%>
        <div class="overflow-x-auto -mx-4 px-4">
          <div
            class="inline-grid gap-px bg-base-300 rounded-box overflow-hidden border border-base-300"
            style={"grid-template-columns: auto repeat(#{length(slot_days(@poll.slots))}, minmax(5rem, 1fr));"}
          >
            <%!-- Header row: empty corner + day labels --%>
            <div class="bg-base-200 px-2 py-2.5 text-xs font-medium text-base-content/40 sticky left-0 z-10">
            </div>
            <div
              :for={day <- slot_days(@poll.slots)}
              class="bg-base-200 px-2 py-2.5 text-center"
            >
              <div class="text-xs font-medium text-base-content/50">
                {Calendar.strftime(day, "%a")}
              </div>
              <div class="text-sm font-bold">
                {Calendar.strftime(day, "%d/%m")}
              </div>
            </div>

            <%!-- Data rows: time label + slot cells --%>
            <%= for time <- slot_times(@poll.slots) do %>
              <div class="bg-base-100 px-2 py-3 text-xs font-mono text-base-content/50
                        flex items-center sticky left-0 z-10">
                {Calendar.strftime(time, "%H:%M")}
              </div>
              <%= for day <- slot_days(@poll.slots) do %>
                <%= if slot = find_slot(@poll.slots, day, time) do %>
                  <div
                    id={"slot-#{slot.id}"}
                    phx-click={if @participant && @poll.status == :open, do: "toggle_slot"}
                    phx-value-slot-id={slot.id}
                    class={[
                      "h-full min-h-[2.75rem] flex items-center justify-center transition-colors",
                      slot_cell_class(slot, @participant, @poll)
                    ]}
                  >
                    <span
                      :if={@role == :admin && unavailability_count(slot, @poll) > 0}
                      class="text-xs font-bold opacity-70"
                    >
                      {unavailability_count(slot, @poll)}
                    </span>
                    <.icon
                      :if={@poll.status == :resolved && @poll.resolved_slot_id == slot.id}
                      name="hero-star-solid"
                      class="size-5 text-success"
                    />
                  </div>
                <% else %>
                  <div class="bg-base-200/50 min-h-[2.75rem]"></div>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Legend --%>
        <div class="mt-4 flex flex-wrap gap-4 text-xs text-base-content/50">
          <div class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-base-100 border border-base-300"></span>
            {gettext("Available")}
          </div>
          <div class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-error/20 border border-error/40"></span>
            {gettext("You can't")}
          </div>
          <div :if={@role == :admin} class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-error/40 border border-error/60"></span>
            {gettext("Others can't (count shown)")}
          </div>
          <div :if={@poll.status == :resolved} class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-success/20 border border-success/40">
            </span>
            {gettext("Winner")}
          </div>
        </div>

        <%!-- Participants list --%>
        <div :if={length(@poll.participants) > 0} class="mt-6">
          <h2 class="text-sm font-semibold mb-2 text-base-content/60">
            {gettext("Participants (%{count})", count: length(@poll.participants))}
          </h2>
          <div class="flex flex-wrap gap-2">
            <span :for={p <- @poll.participants} class="badge badge-lg badge-soft">
              {p.name}
              <span :if={p.is_organizer} class="text-xs text-primary ml-0.5">
                {gettext("(organizer)")}
              </span>
            </span>
          </div>
        </div>

        <%!-- Close button for admin --%>
        <button
          :if={@role == :admin && @poll.status == :open}
          id="close-poll"
          phx-click="close_poll"
          data-confirm={gettext("This will find the best slot and close the poll. Proceed?")}
          class="mt-8 btn btn-error btn-soft w-full"
        >
          <.icon name="hero-lock-closed" class="size-4" />
          {gettext("Close poll and find the best slot")}
        </button>
      <% end %>
    </div>
    """
  end
end
