defmodule PhoenixFintech.Repo.Migrations.RemoveTransferQuotesPartyForeignKeys do
  use Ecto.Migration

  def up do
    drop_if_exists constraint(:transfer_quotes, :transfer_quotes_originator_party_id_fkey)
    drop_if_exists constraint(:transfer_quotes, :transfer_quotes_counterparty_party_id_fkey)
  end

  def down do
    alter table(:transfer_quotes) do
      modify :originator_party_id,
             references(:parties, type: :binary_id, on_delete: :restrict),
             null: false

      modify :counterparty_party_id,
             references(:parties, type: :binary_id, on_delete: :restrict),
             null: false
    end
  end
end
