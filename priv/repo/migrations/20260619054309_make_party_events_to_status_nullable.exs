defmodule PhoenixFintech.Repo.Migrations.MakePartyEventsToStatusNullable do
  use Ecto.Migration

  # `party_events.to_status` was NOT NULL because every event used to be a
  # state-machine transition (which always has a target status). We now also
  # record non-state-machine events (e.g. `originator_status_granted`), for
  # which neither `from_status` nor `to_status` are meaningful. Relax
  # `to_status` to nullable so those events can be persisted.
  def up do
    alter table(:party_events) do
      modify :to_status, :string, null: true
    end
  end

  def down do
    execute "DELETE FROM party_events WHERE to_status IS NULL", ""

    alter table(:party_events) do
      modify :to_status, :string, null: false
    end
  end
end
