defmodule PhoenixFintech.Notifications.Notification do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @cta_types ~w(party transfer compliance_review)

  schema "notifications" do
    field :message, :string
    field :cta_type, :string
    field :cta_id, :string
    field :read_at, :utc_datetime

    belongs_to :user, PhoenixFintech.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def cta_types, do: @cta_types

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :message, :cta_type, :cta_id, :read_at])
    |> validate_required([:user_id, :message, :cta_type])
    |> validate_inclusion(:cta_type, @cta_types)
    |> foreign_key_constraint(:user_id)
  end
end
