defmodule Oggi.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    create table(:polls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :string
      add :meeting_duration, :integer, null: false
      add :date_range_start, :date, null: false
      add :date_range_end, :date, null: false
      add :admin_token, :string, null: false
      add :participant_token, :string, null: false
      add :status, :string, null: false, default: "open"
      add :resolved_slot_id, :binary_id

      timestamps()
    end

    create unique_index(:polls, [:admin_token])
    create unique_index(:polls, [:participant_token])

    create table(:slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false
      add :start_time, :naive_datetime, null: false
      add :end_time, :naive_datetime, null: false
    end

    create unique_index(:slots, [:poll_id, :start_time])

    create table(:participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :is_organizer, :boolean, null: false, default: false
    end

    create table(:unavailabilities, primary_key: false) do
      add :participant_id, references(:participants, type: :binary_id, on_delete: :delete_all),
        null: false

      add :slot_id, references(:slots, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:unavailabilities, [:participant_id, :slot_id])
  end
end
