defmodule PhoenixFintech.Repo.Migrations.CreatePartiesPartyMembersAndGovernmentIds do
  use Ecto.Migration

  def change do
    create table(:parties, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tax_id, :string, null: false
      add :legal_name, :string, null: false
      add :address_line1, :string, null: false
      add :address_line2, :string
      add :locality, :string, null: false
      add :region, :string, null: false
      add :postal_code, :string, null: false
      add :country_code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:parties, [:tax_id])

    create table(:party_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :party_id, references(:parties, type: :binary_id, on_delete: :delete_all), null: false

      add :parent_party_member_id,
          references(:party_members, type: :binary_id, on_delete: :nilify_all)

      add :legal_name, :string, null: false
      add :type, :string, null: false
      add :title, :string
      add :is_legal_rep, :boolean, null: false, default: false
      add :is_ubo, :boolean, null: false, default: false
      add :address_line1, :string, null: false
      add :address_line2, :string
      add :locality, :string, null: false
      add :region, :string, null: false
      add :postal_code, :string, null: false
      add :country_code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:party_members, [:party_id])
    create index(:party_members, [:parent_party_member_id])

    create table(:government_ids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :party_id, references(:parties, type: :binary_id, on_delete: :delete_all)
      add :party_member_id, references(:party_members, type: :binary_id, on_delete: :delete_all)
      add :type, :string, null: false
      add :country_code, :string, null: false
      add :value, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:government_ids, [:party_id])
    create index(:government_ids, [:party_member_id])

    create constraint(:government_ids, :government_ids_exactly_one_owner,
             check: "(party_id IS NOT NULL)::int + (party_member_id IS NOT NULL)::int = 1"
           )
  end
end
