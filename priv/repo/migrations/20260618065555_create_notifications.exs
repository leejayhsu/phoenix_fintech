defmodule PhoenixFintech.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :message, :string, null: false
      add :cta_type, :string, null: false
      add :cta_id, :string
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:inserted_at])
  end
end
