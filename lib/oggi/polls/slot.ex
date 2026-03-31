defmodule Oggi.Polls.Slot do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "slots" do
    field :start_time, :naive_datetime
    field :end_time, :naive_datetime

    belongs_to :poll, Oggi.Polls.Poll
    has_many :unavailabilities, Oggi.Polls.Unavailability
  end
end
