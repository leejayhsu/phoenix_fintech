defmodule PhoenixFintech.Repo.Migrations.CreateTransfersAndFxQuotes do
  use Ecto.Migration

  def change do
    create table(:transfer_fx_quotes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :provider_quote_reference, :string
      add :base_currency_code, references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false
      add :quote_currency_code, references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false
      add :rate, :decimal, null: false
      add :quoted_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transfer_fx_quotes, [:provider_quote_reference])

    create table(:transfers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :originator_party_id, references(:parties, type: :binary_id, on_delete: :restrict), null: false
      add :counterparty_party_id, references(:parties, type: :binary_id, on_delete: :restrict), null: false
      add :fx_quote_id, references(:transfer_fx_quotes, type: :binary_id, on_delete: :nilify_all)
      add :originator_currency_code, references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false
      add :counterparty_currency_code, references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false
      add :amount_in_originator_currency, :decimal, null: false
      add :amount_in_counterparty_currency, :decimal, null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transfers, [:created_by_user_id])
    create index(:transfers, [:originator_party_id])
    create index(:transfers, [:counterparty_party_id])
    create index(:transfers, [:fx_quote_id])
    create constraint(:transfers, :transfers_distinct_parties_check, check: "originator_party_id <> counterparty_party_id")
    create constraint(:transfers, :transfers_originator_amount_gt_zero, check: "amount_in_originator_currency > 0")
    create constraint(:transfers, :transfers_counterparty_amount_gt_zero, check: "amount_in_counterparty_currency > 0")
  end
end
