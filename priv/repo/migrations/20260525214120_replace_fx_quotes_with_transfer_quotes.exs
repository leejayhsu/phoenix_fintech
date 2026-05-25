defmodule PhoenixFintech.Repo.Migrations.ReplaceFxQuotesWithTransferQuotes do
  use Ecto.Migration

  def up do
    drop_if_exists index(:transfers, [:fx_quote_id])

    alter table(:transfers) do
      remove :fx_quote_id
    end

    drop table(:transfer_fx_quotes)

    create table(:transfer_quotes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false

      add :originator_party_id, references(:parties, type: :binary_id, on_delete: :restrict),
        null: false

      add :counterparty_party_id, references(:parties, type: :binary_id, on_delete: :restrict),
        null: false

      add :originator_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :counterparty_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :amount_in_originator_currency, :decimal, null: false
      add :amount_in_counterparty_currency, :decimal, null: false
      add :input_snapshot, :map, null: false
      add :calculation_snapshot, :map, null: false
      add :expires_at, :utc_datetime
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:transfer_quotes, [:created_by_user_id])
    create index(:transfer_quotes, [:originator_party_id])
    create index(:transfer_quotes, [:counterparty_party_id])

    alter table(:transfers) do
      add :transfer_quote_id,
          references(:transfer_quotes, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:transfers, [:transfer_quote_id])
  end

  def down do
    drop_if_exists index(:transfers, [:transfer_quote_id])

    alter table(:transfers) do
      remove :transfer_quote_id
    end

    drop table(:transfer_quotes)

    create table(:transfer_fx_quotes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :provider_quote_reference, :string

      add :base_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :quote_currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :rate, :decimal, null: false
      add :quoted_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transfer_fx_quotes, [:provider_quote_reference])

    alter table(:transfers) do
      add :fx_quote_id, references(:transfer_fx_quotes, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:transfers, [:fx_quote_id])
  end
end
