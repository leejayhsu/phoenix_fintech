defmodule PhoenixFintech.Transfers.TransferEvent do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfer_events" do
    field :event_type, :string
    field :from_status, :string
    field :to_status, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :transfer, PhoenixFintech.Transfers.Transfer
    belongs_to :actor_user, PhoenixFintech.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :transfer_id,
      :actor_user_id,
      :event_type,
      :from_status,
      :to_status,
      :metadata,
      :occurred_at
    ])
    |> validate_required([:transfer_id, :event_type, :to_status, :occurred_at])
    |> validate_length(:event_type, max: 100)
    |> validate_length(:from_status, max: 100)
    |> validate_length(:to_status, max: 100)
    |> assoc_constraint(:transfer)
    |> assoc_constraint(:actor_user)
  end
end
