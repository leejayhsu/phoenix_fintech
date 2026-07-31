defmodule PhoenixFintech.Repo.Migrations.AddReusableTransferQuotes do
  use Ecto.Migration

  def change do
    alter table(:transfer_quotes) do
      add :reusable, :boolean, null: false, default: false

      add :source_quote_id,
          references(:transfer_quotes, type: :binary_id, on_delete: :nilify_all)

      modify :originator_party_id, :binary_id, null: true
      modify :counterparty_party_id, :binary_id, null: true
      modify :amount_in_originator_currency, :decimal, null: true
      modify :amount_in_counterparty_currency, :decimal, null: true
      modify :spread_amount, :decimal, null: true
    end

    create index(:transfer_quotes, [:source_quote_id])
    create index(:transfer_quotes, [:created_by_user_id, :reusable, :expires_at])
  end
end
