defmodule PhoenixFintech.Repo.Migrations.MakePartyAddressFieldsNullable do
  use Ecto.Migration

  def change do
    alter table(:parties) do
      modify :address_line1, :string, null: true, from: {:string, null: false}
      modify :locality, :string, null: true, from: {:string, null: false}
      modify :region, :string, null: true, from: {:string, null: false}
      modify :postal_code, :string, null: true, from: {:string, null: false}
      modify :country_code, :string, null: true, from: {:string, null: false}
    end
  end
end
