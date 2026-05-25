defmodule PhoenixFintech.Repo.Migrations.CreateLedgerTables do
  use Ecto.Migration

  def change do
    create table(:currencies, primary_key: false) do
      add :code, :string, primary_key: true
      add :name, :string, null: false
      add :minor_unit, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:currencies, :currencies_code_length_check, check: "char_length(code) = 3")

    create constraint(:currencies, :currencies_minor_unit_range_check,
             check: "minor_unit >= 0 and minor_unit <= 6"
           )

    create table(:ledger_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :name, :string, null: false
      add :is_negative_balance_allowed, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create table(:ledger_account_balances, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :ledger_account_id,
          references(:ledger_accounts, type: :binary_id, on_delete: :delete_all), null: false

      add :currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      add :pending_balance, :decimal, null: false, default: 0
      add :available_balance, :decimal, null: false, default: 0
      add :posted_balance, :decimal, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:ledger_account_balances, [:ledger_account_id, :currency_code])

    create table(:ledger_journal_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_type, :string
      add :source_id, :binary_id
      add :party_id, references(:parties, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false
      add :type, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:ledger_journal_entries, [:source_type, :source_id])
    create index(:ledger_journal_entries, [:party_id])

    create constraint(:ledger_journal_entries, :source_type_source_id_pair_check,
             check:
               "(source_type IS NULL AND source_id IS NULL) OR (source_type IS NOT NULL AND source_id IS NOT NULL)"
           )

    create table(:ledger_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :ledger_journal_entry_id,
          references(:ledger_journal_entries, type: :binary_id, on_delete: :delete_all),
          null: false

      add :ledger_account_id,
          references(:ledger_accounts, type: :binary_id, on_delete: :restrict), null: false

      add :amount, :decimal, null: false
      add :direction, :string, null: false

      add :currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:ledger_entries, :ledger_entries_amount_gt_zero, check: "amount > 0")
    create index(:ledger_entries, [:ledger_journal_entry_id])
    create index(:ledger_entries, [:ledger_account_id])
    create index(:ledger_entries, [:currency_code])
  end
end
