defmodule Oggi.Polls.Poll do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "polls" do
    field :title, :string
    field :description, :string
    field :meeting_duration, :integer
    field :date_range_start, :date
    field :date_range_end, :date
    field :admin_token, :string
    field :participant_token, :string
    field :status, Ecto.Enum, values: [:open, :closed, :resolved]

    belongs_to :resolved_slot, Oggi.Polls.Slot
    has_many :slots, Oggi.Polls.Slot
    has_many :participants, Oggi.Polls.Participant

    timestamps()
  end

  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:title, :description, :meeting_duration, :date_range_start, :date_range_end])
    |> validate_required([:title, :meeting_duration, :date_range_start, :date_range_end])
    |> validate_number(:meeting_duration, greater_than: 0)
    |> validate_date_range()
    |> put_tokens()
    |> put_change(:status, :open)
  end

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :date_range_start)
    end_date = get_field(changeset, :date_range_end)

    case {start_date, end_date} do
      {nil, _} -> changeset
      {_, nil} -> changeset
      {s, e} ->
        if Date.compare(s, e) == :gt do
          add_error(changeset, :date_range_end, "must be after start date")
        else
          changeset
        end
    end
  end

  defp put_tokens(changeset) do
    changeset
    |> put_change(:admin_token, generate_token())
    |> put_change(:participant_token, generate_token())
  end

  defp generate_token, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
end
