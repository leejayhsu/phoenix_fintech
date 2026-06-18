defmodule PhoenixFintech.Notifications do
  @moduledoc """
  Context for in-app notifications.
  """
  import Ecto.Query, warn: false

  alias PhoenixFintech.Notifications.Notification
  alias PhoenixFintech.Repo

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
  Creates a notification.
  """
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Marks a single notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Notification.changeset(%{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  @doc """
  Marks all unread notifications for a user as read.
  """
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      set: [read_at: now]
    )
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
  """
  def notify_party_approved(party, user_id) do
    create_notification(%{
      user_id: user_id,
      message: "Your party \"#{party.legal_name}\" has been approved by compliance.",
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
