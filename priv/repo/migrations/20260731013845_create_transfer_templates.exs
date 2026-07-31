defmodule PhoenixFintech.Repo.Migrations.CreateTransferTemplates do
  use Ecto.Migration

  def change do
    create table(:transfer_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :originator_party_id,
          references(:parties, type: :binary_id, on_delete: :delete_all), null: false

      add :counterparty_party_id,
          references(:parties, type: :binary_id, on_delete: :delete_all), null: false

      add :originator_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :counterparty_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :spread_basis_points, :integer, null: false
      add :direction, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transfer_templates, [:user_id])
    create index(:transfer_templates, [:originator_party_id])
    create index(:transfer_templates, [:counterparty_party_id])

    create constraint(:transfer_templates, :transfer_templates_distinct_parties_check,
             check: "originator_party_id <> counterparty_party_id"
           )

    create constraint(:transfer_templates, :transfer_templates_spread_range,
             check: "spread_basis_points >= 0 and spread_basis_points < 10000"
           )

    create constraint(:transfer_templates, :transfer_templates_direction_check,
             check: "direction in ('send', 'receive')"
           )
  end
end
