defmodule PhoenixFintech.Repo.Migrations.RemovePartyMemberAddressFields do
  use Ecto.Migration

  def change do
    alter table(:party_members) do
      remove :address_line1, :string
      remove :address_line2, :string
      remove :locality, :string
      remove :region, :string
      remove :postal_code, :string
    end
  end
end
