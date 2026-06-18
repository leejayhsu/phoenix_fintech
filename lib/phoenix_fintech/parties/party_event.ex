defmodule PhoenixFintech.Parties.PartyEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "party_events" do
    field :event_type, :string
    field :from_status, :string
    field :to_status, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :party, PhoenixFintech.Parties.Party
    belongs_to :actor_user, PhoenixFintech.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :party_id,
      :actor_user_id,
      :event_type,
      :from_status,
      :to_status,
      :metadata,
      :occurred_at
    ])
    |> validate_required([:party_id, :event_type, :to_status, :occurred_at])
    |> validate_length(:event_type, max: 100)
    |> validate_length(:from_status, max: 100)
    |> validate_length(:to_status, max: 100)
    |> assoc_constraint(:party)
    |> assoc_constraint(:actor_user)
  end
end
