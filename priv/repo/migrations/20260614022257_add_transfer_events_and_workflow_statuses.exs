defmodule PhoenixFintech.Repo.Migrations.AddTransferEventsAndWorkflowStatuses do
  use Ecto.Migration

  def up do
    create table(:transfer_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transfer_id, references(:transfers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transfer_events, [:transfer_id, :occurred_at])
    create index(:transfer_events, [:actor_user_id])
    create index(:transfer_events, [:event_type])

    execute """
    UPDATE transfers
    SET status = CASE status
      WHEN 'draft' THEN 'created'
      WHEN 'quoted' THEN 'compliance_review'
      WHEN 'submitted' THEN 'deposit_pending'
      ELSE status
    END
    """
  end

  def down do
    execute """
    UPDATE transfers
    SET status = CASE status
      WHEN 'created' THEN 'draft'
      WHEN 'originator_set' THEN 'draft'
      WHEN 'counterparty_set' THEN 'draft'
      WHEN 'fx_quote_confirmed' THEN 'quoted'
      WHEN 'compliance_review' THEN 'quoted'
      WHEN 'compliance_approved' THEN 'submitted'
      WHEN 'deposit_pending' THEN 'submitted'
      WHEN 'deposit_received' THEN 'submitted'
      WHEN 'disbursement_pending' THEN 'submitted'
      WHEN 'disbursement_initiated' THEN 'submitted'
      WHEN 'disbursement_settled' THEN 'submitted'
      WHEN 'completed' THEN 'submitted'
      WHEN 'cancelled' THEN 'draft'
      WHEN 'compliance_rejected' THEN 'submitted'
      ELSE status
    END
    """

    drop table(:transfer_events)
  end
end
