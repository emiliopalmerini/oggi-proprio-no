defmodule Oggi.Polls.Participant do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "participants" do
    field :name, :string
    field :is_organizer, :boolean, default: false

    belongs_to :poll, Oggi.Polls.Poll
    has_many :unavailabilities, Oggi.Polls.Unavailability
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:name, :is_organizer])
    |> validate_required([:name])
  end
end
