defmodule PhoenixFintech.Transfers.TransferTemplate do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfer_templates" do
    field :originator_currency_code, :string
    field :counterparty_currency_code, :string
    field :spread_basis_points, :integer
    field :direction, Ecto.Enum, values: [:send, :receive]

    belongs_to :user, PhoenixFintech.Accounts.User
    belongs_to :originator_party, PhoenixFintech.Parties.Party
    belongs_to :counterparty_party, PhoenixFintech.Parties.Party

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :spread_basis_points,
      :direction
    ])
    |> update_change(:originator_currency_code, &String.upcase/1)
    |> update_change(:counterparty_currency_code, &String.upcase/1)
    |> validate_required([
      :user_id,
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :spread_basis_points,
      :direction
    ])
    |> validate_length(:originator_currency_code, is: 3)
    |> validate_length(:counterparty_currency_code, is: 3)
    |> validate_number(:spread_basis_points, greater_than_or_equal_to: 0, less_than: 10_000)
    |> assoc_constraint(:user)
    |> assoc_constraint(:originator_party)
    |> assoc_constraint(:counterparty_party)
    |> foreign_key_constraint(:originator_currency_code)
    |> foreign_key_constraint(:counterparty_currency_code)
    |> check_constraint(:counterparty_party_id,
      name: :transfer_templates_distinct_parties_check,
      message: "must be different from originator party"
    )
    |> check_constraint(:spread_basis_points, name: :transfer_templates_spread_range)
    |> check_constraint(:direction, name: :transfer_templates_direction_check)
  end
end
