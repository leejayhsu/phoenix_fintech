defmodule PhoenixFintech.Notifications do
  @moduledoc """
  Context for in-app notifications.
  """
  import Ecto.Query, warn: false

  alias PhoenixFintech.Notifications.Notification
  alias PhoenixFintech.PubSub
  alias PhoenixFintech.Repo

  @doc """
  PubSub topic for a user's notification stream.
  """
  def topic(user_id), do: "notifications:user:#{user_id}"

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(PubSub, topic(user_id), message)
  end

  @doc """
  Lists the most recent notifications for a user, newest first.
  """
  def list_notifications_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Returns the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    Repo.one(
      from n in Notification,
        where: n.user_id == ^user_id and is_nil(n.read_at),
        select: count(n.id)
    )
  end

  @doc """
  Creates a notification and broadcasts it to the user's notification stream.
  """
  def create_notification(attrs) do
    with {:ok, notification} <-
           %Notification{}
           |> Notification.changeset(attrs)
           |> Repo.insert() do
      broadcast(notification.user_id, {:notification_created, notification})
      {:ok, notification}
    end
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Marks a single notification as read and broadcasts the change.
  """
  def mark_as_read(%Notification{} = notification) do
    with {:ok, updated} <-
           notification
           |> Notification.changeset(%{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
           |> Repo.update() do
      broadcast(updated.user_id, {:notification_read, updated})
      {:ok, updated}
    end
  end

  @doc """
  Marks all unread notifications for a user as read and broadcasts the change.
  """
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      Repo.update_all(
        from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
        set: [read_at: now]
      )

    broadcast(user_id, {:notifications_all_read, user_id})
    result
  end

  @doc """
  Builds a notification that a party has entered compliance review.
  """
  def notify_party_in_compliance_review(party, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Your party \"#{party.legal_name}\" is now in compliance review.",
      cta_type: "party",
      cta_id: party.id
    })
  end

  @doc """
  Builds a notification that a party has been approved by compliance.

  The message is tailored to the review's purpose:

    * `"onboarding"` - the initial compliance review, allowing the party to
      transact as a counterparty.
    * `"originator_status"` - grants the party originator privileges.
  """
  def notify_party_approved(party, purpose, user_id) do
    message =
      case purpose do
        "originator_status" ->
          "#{party.legal_name} has been approved to transact as an originator"

        _ ->
          "#{party.legal_name} has been approved to transact as a counterparty"
      end

    create_notification(%{
      user_id: user_id,
      message: message,
      cta_type: "party",
      cta_id: party.id
    })
  end

  @doc """
  Builds a notification that a party has been rejected by compliance.
  """
  def notify_party_rejected(party, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Your party \"#{party.legal_name}\" was rejected by compliance.",
      cta_type: "party",
      cta_id: party.id
    })
  end

  @doc """
  Builds a notification that a party has been sent for manual review.
  """
  def notify_party_in_manual_review(party, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Your party \"#{party.legal_name}\" has been queued for manual compliance review.",
      cta_type: "party",
      cta_id: party.id
    })
  end

  @doc """
  Notifies the transfer's owner that the transfer has been submitted for
  compliance review.
  """
  def notify_transfer_in_compliance_review(transfer, review_id, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Transfer #{short_id(transfer.id)} has been submitted for compliance review.",
      cta_type: "compliance_review",
      cta_id: review_id
    })
  end

  @doc """
  Notifies the transfer's owner that compliance has approved their transfer.
  """
  def notify_transfer_compliance_approved(transfer, review_id, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Transfer #{short_id(transfer.id)} has been approved by compliance.",
      cta_type: "compliance_review",
      cta_id: review_id
    })
  end

  @doc """
  Notifies the transfer's owner that compliance has rejected their transfer.
  """
  def notify_transfer_compliance_rejected(transfer, review_id, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Transfer #{short_id(transfer.id)} was rejected by compliance.",
      cta_type: "compliance_review",
      cta_id: review_id
    })
  end

  @doc """
  Notifies the transfer's owner that compliance has queued their transfer for
  manual review.
  """
  def notify_transfer_compliance_in_manual_review(transfer, review_id, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Transfer #{short_id(transfer.id)} has been queued for manual compliance review.",
      cta_type: "compliance_review",
      cta_id: review_id
    })
  end

  @doc """
  Notifies the transfer's owner that the incoming deposit has been received.
  """
  def notify_transfer_deposit_received(transfer, user_id) do
    create_notification(%{
      user_id: user_id,
      message:
        "Deposit received for transfer #{short_id(transfer.id)} — funds are being prepared for disbursement.",
      cta_type: "transfer",
      cta_id: transfer.id
    })
  end

  @doc """
  Notifies the transfer's owner that the disbursement has been initiated.
  """
  def notify_transfer_disbursement_initiated(transfer, user_id) do
    create_notification(%{
      user_id: user_id,
      message:
        "Disbursement initiated for transfer #{short_id(transfer.id)} — funds are on their way.",
      cta_type: "transfer",
      cta_id: transfer.id
    })
  end

  @doc """
  Notifies the transfer's owner that the disbursement has settled and the
  transfer is complete.
  """
  def notify_transfer_disbursement_settled(transfer, user_id) do
    create_notification(%{
      user_id: user_id,
      message:
        "Disbursement settled for transfer #{short_id(transfer.id)} — the transfer is complete.",
      cta_type: "transfer",
      cta_id: transfer.id
    })
  end

  @doc """
  Resolves a notification's CTA to a path, or nil when no link applies.
  """
  def cta_path(%Notification{cta_type: "party", cta_id: id}) when is_binary(id),
    do: "/app/parties/#{id}"

  def cta_path(%Notification{cta_type: "compliance_review", cta_id: id})
      when is_binary(id),
      do: "/admin/compliance_reviews/#{id}"

  def cta_path(%Notification{cta_type: "transfer", cta_id: id}) when is_binary(id),
    do: "/app/transfers/#{id}"

  def cta_path(_), do: nil

  defp short_id(id) when is_binary(id) do
    case String.split(id, "-") do
      [prefix | _] when byte_size(prefix) >= 8 -> String.slice(prefix, 0, 8)
      _ -> id
    end
  end

  defp short_id(id), do: to_string(id)
end
