defmodule PhoenixFintech.Repo.Migrations.AddCanOriginateToParties do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      add :can_originate, :boolean, default: false, null: false
    end
  end
end
