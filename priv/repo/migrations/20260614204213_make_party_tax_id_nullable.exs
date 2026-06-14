defmodule PhoenixFintech.Repo.Migrations.MakePartyTaxIdNullable do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      modify :tax_id, :string, null: true, from: {:string, null: false}
    end
  end
end
