defmodule PhoenixFintech.Transfers.TransferStateMachine do
  use Machinery,
    field: :status,
    states: [
      "created",
      "originator_set",
      "counterparty_set",
      "fx_quote_confirmed",
      "compliance_review",
      "compliance_approved",
      "compliance_rejected",
      "deposit_pending",
      "deposit_received",
      "disbursement_pending",
      "disbursement_initiated",
      "disbursement_settled",
      "completed",
      "cancelled"
    ],
    transitions: %{
      "created" => ["originator_set", "cancelled"],
      "originator_set" => ["counterparty_set", "cancelled"],
      "counterparty_set" => ["fx_quote_confirmed", "cancelled"],
      "fx_quote_confirmed" => ["compliance_review", "cancelled"],
      "compliance_review" => ["compliance_approved", "compliance_rejected", "cancelled"],
      "compliance_approved" => ["deposit_pending", "cancelled"],
      "deposit_pending" => ["deposit_received", "cancelled"],
      "deposit_received" => "disbursement_pending",
      "disbursement_pending" => "disbursement_initiated",
      "disbursement_initiated" => "disbursement_settled",
      "disbursement_settled" => "completed"
    }

  alias PhoenixFintech.Transfers

  def guard_transition(transfer, "originator_set", _metadata) do
    if is_nil(transfer.originator_party_id) do
      {:error, "originator must be set"}
    end
  end

  def guard_transition(transfer, "counterparty_set", _metadata) do
    if is_nil(transfer.counterparty_party_id) do
      {:error, "counterparty must be set"}
    end
  end

  def guard_transition(transfer, "fx_quote_confirmed", _metadata) do
    if is_nil(transfer.transfer_quote_id) do
      {:error, "fx quote must be confirmed"}
    end
  end

  def persist(transfer, next_status, metadata) do
    Transfers.persist_transfer_transition!(transfer, next_status, metadata)
  end
end
