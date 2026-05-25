defmodule PhoenixFintech.Repo.Migrations.AddCreatedByUserToParties do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :restrict)
    end

    create index(:parties, [:created_by_user_id])
  end
end
