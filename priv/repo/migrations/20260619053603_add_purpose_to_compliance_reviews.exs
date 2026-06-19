defmodule PhoenixFintech.Repo.Migrations.AddPurposeToComplianceReviews do
  use Ecto.Migration

  def up do
    alter table(:compliance_reviews) do
      add :purpose, :string, default: "onboarding", null: false
    end

    flush()

    # Backfill any rows that slipped through (defensive: the column is NOT
    # NULL with a default, so this is a no-op on Postgres, but keeps the
    # migration explicit and reversible).
    execute(
      "UPDATE compliance_reviews SET purpose = 'onboarding' WHERE purpose IS NULL",
      ""
    )

    # A party may now carry one onboarding review AND one originator_status
    # review, so the unique index on `party_id` alone is too narrow. Drop it
    # and replace it with a composite unique index on `(party_id, purpose)`.
    execute(
      "DROP INDEX IF EXISTS compliance_reviews_party_id_unique_index",
      "CREATE UNIQUE INDEX compliance_reviews_party_id_unique_index " <>
        "ON compliance_reviews (party_id) WHERE party_id IS NOT NULL"
    )

    execute(
      "CREATE UNIQUE INDEX compliance_reviews_party_id_purpose_unique_index " <>
        "ON compliance_reviews (party_id, purpose) WHERE party_id IS NOT NULL",
      "DROP INDEX IF EXISTS compliance_reviews_party_id_purpose_unique_index"
    )

    execute(
      "ALTER TABLE compliance_reviews " <>
        "ADD CONSTRAINT compliance_reviews_purpose_check " <>
        "CHECK (purpose IN ('onboarding', 'originator_status'))",
      "ALTER TABLE compliance_reviews " <>
        "DROP CONSTRAINT IF EXISTS compliance_reviews_purpose_check"
    )
  end

  def down do
    execute(
      "ALTER TABLE compliance_reviews " <>
        "DROP CONSTRAINT IF EXISTS compliance_reviews_purpose_check",
      ""
    )

    execute(
      "DROP INDEX IF EXISTS compliance_reviews_party_id_purpose_unique_index",
      "CREATE UNIQUE INDEX compliance_reviews_party_id_purpose_unique_index " <>
        "ON compliance_reviews (party_id, purpose) WHERE party_id IS NOT NULL"
    )

    execute(
      "CREATE UNIQUE INDEX compliance_reviews_party_id_unique_index " <>
        "ON compliance_reviews (party_id) WHERE party_id IS NOT NULL",
      "DROP INDEX IF EXISTS compliance_reviews_party_id_unique_index"
    )

    alter table(:compliance_reviews) do
      remove :purpose
    end
  end
end
