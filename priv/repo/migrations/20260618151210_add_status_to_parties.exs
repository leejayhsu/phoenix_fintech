defmodule PhoenixFintech.Repo.Migrations.AddStatusToParties do
  use Ecto.Migration

  def up do
    alter table(:parties) do
      add :status, :string, null: false, default: "created"
    end

    create index(:parties, [:status])

    # Backfill party status from each party's existing compliance review so
    # onboarded parties do not get stuck in "created". Parties without a
    # review remain "created".
    execute """
    UPDATE parties p
    SET status = CASE r.status
      WHEN 'created' THEN 'compliance_review'
      WHEN 'manual_review' THEN 'compliance_review'
      WHEN 'approved' THEN 'compliance_approved'
      WHEN 'rejected' THEN 'compliance_rejected'
      ELSE 'compliance_review'
    END
    FROM compliance_reviews r
    WHERE r.party_id = p.id
    """
  end

  def down do
    drop index(:parties, [:status])

    alter table(:parties) do
      remove :status
    end
  end
end
