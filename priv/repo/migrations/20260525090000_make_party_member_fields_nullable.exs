defmodule PhoenixFintech.Repo.Migrations.MakePartyMemberFieldsNullable do
  use Ecto.Migration

  def change do
    alter table(:party_members) do
      modify :legal_name, :string, null: true
      modify :address_line1, :string, null: true
      modify :locality, :string, null: true
      modify :region, :string, null: true
      modify :postal_code, :string, null: true
      modify :country_code, :string, null: true
    end
  end
end
