defmodule PhoenixFintech.Repo.Migrations.CreatePartyComplianceDocuments do
  use Ecto.Migration

  def change do
    create table(:party_compliance_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :party_id, references(:parties, type: :binary_id, on_delete: :delete_all), null: false
      add :uploaded_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :doc_type, :string, null: false
      add :filename, :string, null: false
      add :storage_key, :string, null: false
      add :storage_url, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:party_compliance_documents, [:party_id])
  end
end
