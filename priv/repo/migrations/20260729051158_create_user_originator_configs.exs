defmodule PhoenixFintech.Repo.Migrations.CreateUserOriginatorConfigs do
  use Ecto.Migration

  def change do
    create table(:user_originator_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :originator_party_id,
          references(:parties, type: :binary_id, on_delete: :delete_all), null: false

      add :default_spread_basis_points, :integer, null: false, default: 100

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_originator_configs, [:user_id, :originator_party_id])

    create constraint(
             :user_originator_configs,
             :user_originator_configs_default_spread_range,
             check: "default_spread_basis_points >= 0 and default_spread_basis_points < 10000"
           )
  end
end
