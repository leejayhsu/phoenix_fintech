defmodule PhoenixFintech.Repo.Migrations.CreateDepositsAndDisbursements do
  use Ecto.Migration

  def change do
    create table(:deposits, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transfer_id,
          references(:transfers, type: :binary_id, on_delete: :delete_all),
          null: false

      add :source_party_id, references(:parties, type: :binary_id, on_delete: :restrict),
        null: false

      add :currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict),
          null: false

      add :amount, :decimal, null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:deposits, [:transfer_id])
    create index(:deposits, [:source_party_id])
    create index(:deposits, [:status])

    create constraint(:deposits, :deposits_amount_gt_zero, check: "amount > 0")

    create constraint(:deposits, :deposits_status_check,
             check: "status IN ('pending', 'received', 'failed')"
           )

    create table(:disbursements, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transfer_id,
          references(:transfers, type: :binary_id, on_delete: :delete_all),
          null: false

      add :destination_party_id,
          references(:parties, type: :binary_id, on_delete: :restrict),
          null: false

      add :currency_code,
          references(:currencies, column: :code, type: :string, on_delete: :restrict),
          null: false

      add :amount, :decimal, null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:disbursements, [:transfer_id])
    create index(:disbursements, [:destination_party_id])
    create index(:disbursements, [:status])

    create constraint(:disbursements, :disbursements_amount_gt_zero, check: "amount > 0")

    create constraint(:disbursements, :disbursements_status_check,
             check: "status IN ('pending', 'initiated', 'settled', 'failed')"
           )
  end
end
