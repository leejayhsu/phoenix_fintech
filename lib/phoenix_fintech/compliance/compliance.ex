defmodule PhoenixFintech.Compliance do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Compliance.{Review, ReviewStateMachine}
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Transfers
  alias PhoenixFintech.Transfers.Transfer

  @doc """
  Lists all compliance reviews, newest first.
  """
  def list_reviews do
    Repo.all(
      from r in Review,
        order_by: [desc: r.inserted_at],
        preload: ^review_preloads()
    )
  end

  @doc """
  Lists compliance reviews that still require admin action (created or
  manual_review).
  """
  def list_pending_reviews do
    Repo.all(
      from r in Review,
        where: r.status in ["created", "manual_review"],
        order_by: [asc: r.inserted_at],
        preload: ^review_preloads()
    )
  end

  @doc """
  Lists compliance reviews for a given status.
  """
  @valid_statuses Review.statuses()

  def list_reviews_by_status(status) when status in @valid_statuses do
    Repo.all(
      from r in Review,
        where: r.status == ^status,
        order_by: [desc: r.inserted_at],
        preload: ^review_preloads()
    )
  end

  def get_review!(id) do
    Repo.get!(Review, id)
    |> Repo.preload(review_preloads())
  end

  def get_review_for_transfer(transfer_id) do
    Repo.one(
      from r in Review,
        where: r.transfer_id == ^transfer_id,
        preload: ^review_preloads()
    )
  end

  def get_review_for_party(party_id) do
    Repo.one(
      from r in Review,
        where: r.party_id == ^party_id,
        preload: ^review_preloads()
    )
  end

  def change_review(attrs \\ %{}), do: Review.changeset(%Review{}, attrs)

  @doc """
  Creates a compliance review for the given transfer.
  """
  def create_review_for_transfer(transfer) do
    %Review{}
    |> Review.changeset(%{transfer_id: transfer.id, status: "created"})
    |> Repo.insert()
  end

  @doc """
  Creates a compliance review for the given party.
  """
  def create_review_for_party(party) do
    %Review{}
    |> Review.changeset(%{party_id: party.id, status: "created"})
    |> Repo.insert()
  end

  @doc """
  Moves a compliance review to the next status.

  `metadata` should contain `actor_user_id` and optional `notes`. When the
  review's subject is a transfer, approving or rejecting it also advances the
  transfer's workflow state in the same transaction.
  """
  def transition_review(review, next_status, metadata \\ %{}) do
    metadata = normalize_metadata(metadata)
    review = Repo.preload(review, review_preloads())

    if allowed_transition?(review.status, next_status) do
      run_review_transition(review, next_status, metadata)
    else
      {:error, :transition, "cannot transition from #{review.status} to #{next_status}", %{}}
    end
  end

  def approve_review(review, actor_user, notes \\ nil) do
    transition_review(review, "approved", %{
      actor_user_id: actor_user.id,
      notes: notes
    })
  end

  def reject_review(review, actor_user, notes \\ nil) do
    transition_review(review, "rejected", %{
      actor_user_id: actor_user.id,
      notes: notes
    })
  end

  def request_manual_review(review, actor_user, notes \\ nil) do
    transition_review(review, "manual_review", %{
      actor_user_id: actor_user.id,
      notes: notes
    })
  end

  @doc """
  Returns the set of statuses a review can move to from `status`.
  """
  def allowed_targets(status) do
    Map.get(ReviewStateMachine.transitions(), status, [])
  end

  defp allowed_transition?(status, target) do
    target in allowed_targets(status)
  end

  defp run_review_transition(review, next_status, metadata) do
    review_changeset =
      review
      |> Review.changeset(%{
        status: next_status,
        notes: Map.get(metadata, :notes) || review.notes,
        reviewed_by_user_id: Map.get(metadata, :actor_user_id) || review.reviewed_by_user_id
      })

    transfer_ops = build_transfer_transition_ops(review, next_status, metadata)

    Multi.new()
    |> Multi.update(:review, review_changeset)
    |> then(fn multi -> transfer_ops.(multi, review) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{review: review}} -> {:ok, get_review!(review.id)}
      {:error, step, reason, _changes} -> {:error, step, reason, %{}}
    end
  end

  # When the review's subject is a transfer and the decision is approved or
  # rejected, we also advance the transfer's workflow state. The operations are
  # added to the same Multi so the transition is atomic.
  defp build_transfer_transition_ops(
         %Review{transfer: %Transfer{} = transfer},
         next_status,
         metadata
       ) do
    transfer_target =
      case next_status do
        "approved" -> "compliance_approved"
        "rejected" -> "compliance_rejected"
        _ -> nil
      end

    if transfer_target && transfer.status != transfer_target do
      from_status = transfer.status
      event_metadata = Map.put(metadata, :event_type, "compliance_review_#{next_status}")

      fn multi, _review ->
        multi
        |> Multi.update(:transfer, Transfer.changeset(transfer, %{status: transfer_target}))
        |> Multi.insert(:transfer_event, fn %{transfer: updated_transfer} ->
          Transfers.build_transfer_event_changeset(
            updated_transfer,
            from_status,
            transfer_target,
            event_metadata
          )
        end)
      end
    else
      fn multi, _review -> multi end
    end
  end

  defp build_transfer_transition_ops(_review, _next_status, _metadata) do
    fn multi, _review -> multi end
  end

  defp review_preloads do
    [
      :party,
      :reviewed_by_user,
      transfer: [:originator_party, :counterparty_party]
    ]
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: %{}
end
