defmodule PhoenixFintech.Repo.Migrations.CreateComplianceReviews do
  use Ecto.Migration

  def change do
    create table(:compliance_reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "created"
      add :notes, :text

      add :transfer_id,
          references(:transfers, type: :binary_id, on_delete: :delete_all)

      add :party_id,
          references(:parties, type: :binary_id, on_delete: :delete_all)

      add :reviewed_by_user_id,
          references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:compliance_reviews, [:status])
    create index(:compliance_reviews, [:party_id])
    create index(:compliance_reviews, [:reviewed_by_user_id])

    create unique_index(:compliance_reviews, [:transfer_id],
             where: "transfer_id IS NOT NULL",
             name: :compliance_reviews_transfer_id_index
           )

    create unique_index(:compliance_reviews, [:party_id],
             where: "party_id IS NOT NULL",
             name: :compliance_reviews_party_id_unique_index
           )

    create constraint(:compliance_reviews, :compliance_reviews_subject_present_check,
             check: "(transfer_id IS NOT NULL) <> (party_id IS NOT NULL)"
           )

    create constraint(:compliance_reviews, :compliance_reviews_status_check,
             check: "status IN ('created', 'manual_review', 'approved', 'rejected')"
           )
  end
end
