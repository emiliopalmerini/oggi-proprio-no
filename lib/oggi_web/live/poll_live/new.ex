defmodule OggiWeb.PollLive.New do
  use OggiWeb, :live_view

  alias Oggi.Polls
  alias Oggi.Polls.Poll

  @impl true
  def mount(_params, _session, socket) do
    changeset = Poll.changeset(%Poll{}, %{})
    {:ok, assign(socket, form: to_form(changeset), patterns: [:morning])}
  end

  @impl true
  def handle_event("validate", %{"poll" => poll_params}, socket) do
    changeset =
      %Poll{}
      |> Poll.changeset(poll_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"poll" => poll_params}, socket) do
    patterns =
      socket.assigns.patterns
      |> Enum.map(fn kind -> %{kind: kind, days_of_week: []} end)

    attrs =
      poll_params
      |> Map.put("patterns", patterns)
      |> atomize_keys()

    case Polls.create_poll(attrs) do
      {:ok, poll} ->
        {:noreply, push_navigate(socket, to: "/p/#{poll.admin_token}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
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

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight mb-2">
          Find a time
        </h1>
        <p class="text-base-content/60 text-sm">
          Create a poll. Friends mark when they can't. The rest is magic.
        </p>
      </div>

      <.form for={@form} id="poll-form" phx-change="validate" phx-submit="save" class="space-y-5">
        <.input field={@form[:title]}
                label="What's the occasion?"
                placeholder="Aperitivo, team sync, world domination..." />

        <.input field={@form[:organizer_name]}
                label="Your name"
                placeholder="e.g. Marco" />

        <.input field={@form[:meeting_duration]}
                label="How long? (minutes)"
                type="number"
                value="60" />

        <div class="grid grid-cols-2 gap-3">
          <.input field={@form[:date_range_start]} label="From" type="date" />
          <.input field={@form[:date_range_end]} label="To" type="date" />
        </div>

        <div>
          <span class="label mb-2">When works?</span>
          <div class="flex gap-2">
            <button
              :for={{kind, label, icon} <- [
                {:morning, "Morning", "hero-sun"},
                {:afternoon, "Afternoon", "hero-cloud"},
                {:evening, "Evening", "hero-moon"}
              ]}
              type="button"
              phx-click="toggle_pattern"
              phx-value-kind={kind}
              class={[
                "btn btn-sm flex-1 gap-1.5 transition-all",
                if(kind in @patterns, do: "btn-primary", else: "btn-soft")
              ]}
            >
              <.icon name={icon} class="size-4" />
              {label}
            </button>
          </div>
          <p class="text-xs text-base-content/40 mt-1.5">
            Morning 8-12 / Afternoon 12-18 / Evening 18-22
          </p>
        </div>

        <button type="submit" class="btn btn-primary w-full btn-lg">
          Create poll
        </button>
      </.form>
    </div>
    """
  end
end
