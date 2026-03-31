defmodule Oggi.Polls.Unavailability do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :binary_id

  schema "unavailabilities" do
    belongs_to :participant, Oggi.Polls.Participant
    belongs_to :slot, Oggi.Polls.Slot
  end
end
