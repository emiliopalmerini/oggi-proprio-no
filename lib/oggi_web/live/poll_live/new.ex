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
    <div class="max-w-lg mx-auto mt-10">
      <h1 class="text-2xl font-bold mb-6">Oggi Proprio No</h1>
      <p class="mb-6 text-gray-600">Create a new scheduling poll</p>

      <.form for={@form} id="poll-form" phx-change="validate" phx-submit="save" class="space-y-4">
        <.input field={@form[:title]} label="Title" placeholder="e.g. Team sync, Dinner" />
        <.input field={@form[:organizer_name]} label="Your name" placeholder="e.g. Alice" />
        <.input field={@form[:meeting_duration]} label="Duration (minutes)" type="number" value="60" />
        <.input field={@form[:date_range_start]} label="From" type="date" />
        <.input field={@form[:date_range_end]} label="To" type="date" />

        <div class="space-y-2">
          <label class="block text-sm font-semibold">Time windows</label>
          <div class="flex gap-3">
            <button
              :for={kind <- [:morning, :afternoon, :evening]}
              type="button"
              phx-click="toggle_pattern"
              phx-value-kind={kind}
              class={[
                "px-3 py-1 rounded border text-sm",
                if(kind in @patterns, do: "bg-blue-500 text-white", else: "bg-white text-gray-700")
              ]}
            >
              {kind |> Atom.to_string() |> String.capitalize()}
            </button>
          </div>
        </div>

        <.button type="submit" class="w-full">Create poll</.button>
      </.form>
    </div>
    """
  end
end
