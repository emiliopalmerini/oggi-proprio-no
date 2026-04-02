defmodule OggiWeb.PollLive.New do
  use OggiWeb, :live_view

  alias Oggi.Polls
  alias Oggi.Polls.Poll
  alias Oggi.DateParser

  @impl true
  def mount(_params, _session, socket) do
    changeset = Poll.changeset(%Poll{}, %{})
    parser_loc = parser_locale()
    parsed = parse_input("", parser_loc)

    socket =
      socket
      |> assign(form: to_form(changeset), parser_locale: parser_loc, when_input: "")
      |> assign_parsed(parsed)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"poll" => poll_params}, socket) do
    when_input = Map.get(poll_params, "when_input", socket.assigns.when_input)
    parsed = parse_input(when_input, socket.assigns.parser_locale)

    changeset =
      %Poll{}
      |> Poll.changeset(build_poll_params(poll_params, parsed))
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(form: to_form(changeset), when_input: when_input)
      |> assign_parsed(parsed)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"poll" => poll_params}, socket) do
    when_input = Map.get(poll_params, "when_input", socket.assigns.when_input)
    parsed = parse_input(when_input, socket.assigns.parser_locale)

    patterns =
      parsed.patterns
      |> Enum.map(fn kind -> %{kind: kind, days_of_week: []} end)

    {date_start, date_end} = parsed.date_range

    attrs =
      poll_params
      |> Map.put("date_range_start", Date.to_iso8601(date_start))
      |> Map.put("date_range_end", Date.to_iso8601(date_end))
      |> Map.put("patterns", patterns)
      |> Map.delete("when_input")
      |> atomize_keys()

    case Polls.create_poll(attrs) do
      {:ok, poll} ->
        {:noreply, push_navigate(socket, to: "/p/#{poll.admin_token}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp parse_input(input, locale) do
    {:ok, parsed} = DateParser.parse(input, locale, Date.utc_today())
    parsed
  end

  defp build_poll_params(poll_params, parsed) do
    {date_start, date_end} = parsed.date_range

    poll_params
    |> Map.put("date_range_start", Date.to_iso8601(date_start))
    |> Map.put("date_range_end", Date.to_iso8601(date_end))
  end

  defp parser_locale do
    case Gettext.get_locale(OggiWeb.Gettext) do
      "it" -> :it
      "fr" -> :fr
      "de" -> :de
      "es" -> :es
      _ -> :en
    end
  end

  @windows %{
    morning: "8:00–12:00",
    afternoon: "12:00–18:00",
    evening: "18:00–22:00"
  }

  defp assign_parsed(socket, parsed) do
    {date_start, date_end} = parsed.date_range

    time_ranges =
      parsed.patterns
      |> Enum.map(&Map.fetch!(@windows, &1))

    assign(socket,
      parsed_tokens: parsed.tokens,
      unrecognized: parsed.unrecognized,
      date_start: date_start,
      date_end: date_end,
      time_ranges: time_ranges
    )
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp placeholder(:it), do: "prossima settimana sera"
  defp placeholder(:fr), do: "semaine prochaine soir"
  defp placeholder(:de), do: "nächste Woche Abend"
  defp placeholder(:es), do: "próxima semana noche"
  defp placeholder(_), do: "next week evening"

  @impl true
  def render(assigns) do
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

        <.input
          field={@form[:meeting_duration]}
          label={gettext("How long? (minutes)")}
          type="number"
          value="60"
        />

        <div>
          <.input
            name="poll[when_input]"
            label={gettext("When?")}
            value={@when_input}
            placeholder={placeholder(@parser_locale)}
            autocomplete="off"
          />

          <p class="text-xs text-base-content/40 mt-1.5" id="slot-preview">
            {Calendar.strftime(@date_start, "%a %d %b")}
            <span :if={@date_start != @date_end}>
              &mdash; {Calendar.strftime(@date_end, "%a %d %b")}
            </span>
            <span :if={@time_ranges != []}>
              &middot; {Enum.join(@time_ranges, ", ")}
            </span>
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
