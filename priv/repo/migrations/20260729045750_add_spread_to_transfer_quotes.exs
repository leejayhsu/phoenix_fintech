defmodule PhoenixFintech.Repo.Migrations.AddSpreadToTransferQuotes do
  use Ecto.Migration

  def up do
    alter table(:transfer_quotes) do
      add :spread_basis_points, :integer, null: false, default: 0
      add :spread_amount, :decimal, null: false, default: 0
      add :spot_fx_rate, :decimal
      add :customer_fx_rate, :decimal
    end

    execute("""
    UPDATE transfer_quotes
    SET spot_fx_rate = COALESCE(
          (calculation_snapshot->'facts'->>'fx_rate')::numeric,
          amount_in_counterparty_currency / amount_in_originator_currency
        ),
        customer_fx_rate = COALESCE(
          (calculation_snapshot->'facts'->>'fx_rate')::numeric,
          amount_in_counterparty_currency / amount_in_originator_currency
        )
    """)

    alter table(:transfer_quotes) do
      modify :spot_fx_rate, :decimal, null: false
      modify :customer_fx_rate, :decimal, null: false
    end
  end

  def down do
    alter table(:transfer_quotes) do
      remove :spread_basis_points
      remove :spread_amount
      remove :spot_fx_rate
      remove :customer_fx_rate
    end
  end
end
