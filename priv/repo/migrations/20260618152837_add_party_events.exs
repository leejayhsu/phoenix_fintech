defmodule PhoenixFintech.Repo.Migrations.AddPartyEvents do
  use Ecto.Migration

  def up do
    create table(:party_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :party_id, references(:parties, type: :binary_id, on_delete: :delete_all), null: false

      add :actor_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:party_events, [:party_id, :occurred_at])
    create index(:party_events, [:actor_user_id])
    create index(:party_events, [:event_type])
  end

  def down do
    drop table(:party_events)
  end
end
