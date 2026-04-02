defmodule OggiWeb.PollLive.New do
  use OggiWeb, :live_view

  alias Oggi.Polls
  alias Oggi.Polls.Poll
  alias Oggi.DateParser

  @when_options ~w(this_week next_week this_weekend next_weekend this_month next_month tomorrow)a
  @time_options ~w(morning afternoon evening)a
  @duration_options [30, 60, 90, 120]

  @time_windows %{
    morning: "8:00–12:00",
    afternoon: "12:00–18:00",
    evening: "18:00–22:00"
  }

  @impl true
  def mount(_params, _session, socket) do
    changeset = Poll.changeset(%Poll{}, %{})
    {date_start, date_end} = DateParser.resolve(:next_week, Date.utc_today())

    socket =
      assign(socket,
        form: to_form(changeset),
        when_selected: :next_week,
        patterns: [:evening],
        duration: 60,
        date_start: date_start,
        date_end: date_end
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"poll" => poll_params}, socket) do
    changeset =
      %Poll{}
      |> Poll.changeset(build_poll_params(poll_params, socket))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"poll" => poll_params}, socket) do
    patterns =
      socket.assigns.patterns
      |> Enum.map(fn kind -> %{kind: kind, days_of_week: []} end)

    attrs = %{
      title: Map.get(poll_params, "title"),
      organizer_name: Map.get(poll_params, "organizer_name"),
      meeting_duration: socket.assigns.duration,
      date_range_start: Date.to_iso8601(socket.assigns.date_start),
      date_range_end: Date.to_iso8601(socket.assigns.date_end),
      patterns: patterns
    }

    case Polls.create_poll(attrs) do
      {:ok, poll} ->
        {:noreply, push_navigate(socket, to: "/p/#{poll.admin_token}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("select_when", %{"value" => value}, socket) do
    when_atom = String.to_existing_atom(value)
    {date_start, date_end} = DateParser.resolve(when_atom, Date.utc_today())

    {:noreply,
     assign(socket, when_selected: when_atom, date_start: date_start, date_end: date_end)}
  end

  @impl true
  def handle_event("toggle_pattern", %{"kind" => kind}, socket) do
    kind = String.to_existing_atom(kind)
    patterns = socket.assigns.patterns

    updated =
      if kind in patterns do
        List.delete(patterns, kind)
      else
        patterns ++ [kind]
      end

    {:noreply, assign(socket, patterns: updated)}
  end

  @impl true
  def handle_event("select_duration", %{"value" => value}, socket) do
    {:noreply, assign(socket, duration: String.to_integer(value))}
  end

  defp build_poll_params(poll_params, socket) do
    poll_params
    |> Map.put("date_range_start", Date.to_iso8601(socket.assigns.date_start))
    |> Map.put("date_range_end", Date.to_iso8601(socket.assigns.date_end))
    |> Map.put("meeting_duration", to_string(socket.assigns.duration))
  end

  defp when_label(:this_week), do: gettext("This week")
  defp when_label(:next_week), do: gettext("Next week")
  defp when_label(:this_weekend), do: gettext("This weekend")
  defp when_label(:next_weekend), do: gettext("Next weekend")
  defp when_label(:this_month), do: gettext("This month")
  defp when_label(:next_month), do: gettext("Next month")
  defp when_label(:tomorrow), do: gettext("Tomorrow")

  defp time_label(:morning), do: gettext("Morning")
  defp time_label(:afternoon), do: gettext("Afternoon")
  defp time_label(:evening), do: gettext("Evening")

  defp time_icon(:morning), do: "hero-sun"
  defp time_icon(:afternoon), do: "hero-cloud"
  defp time_icon(:evening), do: "hero-moon"

  defp duration_label(minutes) when minutes < 60, do: gettext("%{n}min", n: minutes)
  defp duration_label(60), do: "1h"
  defp duration_label(minutes), do: "#{div(minutes, 60)}h#{rem(minutes, 60) |> pad()}"

  defp pad(0), do: ""
  defp pad(n), do: "#{n}"

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:when_options, @when_options)
      |> assign(:time_options, @time_options)
      |> assign(:time_windows, @time_windows)
      |> assign(:duration_options, @duration_options)

    ~H"""
    <div class="max-w-md mx-auto">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight mb-2">
          {gettext("Find a time")}
        </h1>
        <p class="text-base-content/60 text-sm">
          {gettext("Create a poll. Friends mark when they can't. The rest is magic.")}
        </p>
      </div>

      <.form for={@form} id="poll-form" phx-change="validate" phx-submit="save" class="space-y-5">
        <.input
          field={@form[:title]}
          label={gettext("What's the occasion?")}
          placeholder={gettext("Aperitivo, team sync, world domination...")}
        />

        <.input
          field={@form[:organizer_name]}
          label={gettext("Your name")}
          placeholder={gettext("e.g. Marco")}
        />

        <div>
          <span class="label mb-2">{gettext("How long?")}</span>
          <div class="flex gap-2">
            <button
              :for={minutes <- @duration_options}
              type="button"
              phx-click="select_duration"
              phx-value-value={minutes}
              class={[
                "btn btn-circle btn-sm transition-all",
                if(minutes == @duration, do: "btn-primary", else: "btn-soft")
              ]}
            >
              {duration_label(minutes)}
            </button>
          </div>
        </div>

        <div>
          <span class="label mb-2">{gettext("When?")}</span>
          <div class="flex flex-wrap gap-1.5">
            <button
              :for={option <- @when_options}
              type="button"
              phx-click="select_when"
              phx-value-value={option}
              class={[
                "btn btn-xs transition-all",
                if(option == @when_selected, do: "btn-primary", else: "btn-soft")
              ]}
            >
              {when_label(option)}
            </button>
          </div>
          <p class="text-xs text-base-content/40 mt-1.5" id="slot-preview">
            {Calendar.strftime(@date_start, "%a %d %b")}
            <span :if={@date_start != @date_end}>
              &mdash; {Calendar.strftime(@date_end, "%a %d %b")}
            </span>
          </p>
        </div>

        <div>
          <span class="label mb-2">{gettext("What time?")}</span>
          <div class="flex gap-2">
            <button
              :for={kind <- @time_options}
              type="button"
              phx-click="toggle_pattern"
              phx-value-kind={kind}
              class={[
                "btn btn-sm flex-1 gap-1.5 transition-all",
                if(kind in @patterns, do: "btn-primary", else: "btn-soft")
              ]}
            >
              <.icon name={time_icon(kind)} class="size-4" />
              {time_label(kind)}
            </button>
          </div>
          <p class="text-xs text-base-content/40 mt-1.5">
            {Enum.map_join(@patterns, ", ", &Map.fetch!(@time_windows, &1))}
          </p>
        </div>

        <button type="submit" class="btn btn-primary w-full btn-lg">
          {gettext("Create poll")}
        </button>
      </.form>
    </div>
    """
  end
end
