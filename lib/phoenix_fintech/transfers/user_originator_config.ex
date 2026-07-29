defmodule PhoenixFintech.Transfers.UserOriginatorConfig do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_originator_configs" do
    field :default_spread_basis_points, :integer, default: 100

    belongs_to :user, PhoenixFintech.Accounts.User
    belongs_to :originator_party, PhoenixFintech.Parties.Party

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:default_spread_basis_points])
    |> validate_required([:default_spread_basis_points])
    |> validate_number(:default_spread_basis_points,
      greater_than_or_equal_to: 0,
      less_than: 10_000
    )
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:originator_party_id)
    |> unique_constraint([:user_id, :originator_party_id])
    |> check_constraint(:default_spread_basis_points,
      name: :user_originator_configs_default_spread_range
    )
  end
end
