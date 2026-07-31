defmodule PhoenixFintech.Transfers.TransferQuote do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfer_quotes" do
    field :originator_currency_code, :string
    field :counterparty_currency_code, :string
    field :amount_in_originator_currency, :decimal
    field :amount_in_counterparty_currency, :decimal
    field :spread_basis_points, :integer
    field :spread_amount, :decimal
    field :spot_fx_rate, :decimal
    field :customer_fx_rate, :decimal
    field :input_snapshot, :map
    field :calculation_snapshot, :map
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime
    field :reusable, :boolean, default: false

    belongs_to :created_by_user, PhoenixFintech.Accounts.User
    belongs_to :originator_party, PhoenixFintech.Parties.Party
    belongs_to :counterparty_party, PhoenixFintech.Parties.Party
    belongs_to :source_quote, __MODULE__

    timestamps(type: :utc_datetime)
  end

  def changeset(quote, attrs) do
    quote
    |> cast(attrs, [
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :amount_in_originator_currency,
      :amount_in_counterparty_currency,
      :spread_basis_points,
      :spread_amount,
      :spot_fx_rate,
      :customer_fx_rate,
      :input_snapshot,
      :calculation_snapshot,
      :expires_at,
      :accepted_at,
      :source_quote_id
    ])
    |> update_change(:originator_currency_code, &String.upcase/1)
    |> update_change(:counterparty_currency_code, &String.upcase/1)
    |> validate_required([
      :created_by_user_id,
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :amount_in_originator_currency,
      :amount_in_counterparty_currency,
      :spread_basis_points,
      :spread_amount,
      :spot_fx_rate,
      :customer_fx_rate,
      :input_snapshot,
      :calculation_snapshot
    ])
    |> validate_number(:amount_in_originator_currency, greater_than: 0)
    |> validate_number(:amount_in_counterparty_currency, greater_than: 0)
    |> validate_number(:spread_basis_points,
      greater_than_or_equal_to: 0,
      less_than: 10_000
    )
    |> validate_number(:spread_amount, greater_than_or_equal_to: 0)
    |> validate_number(:spot_fx_rate, greater_than: 0)
    |> validate_number(:customer_fx_rate, greater_than: 0)
    |> validate_length(:originator_currency_code, is: 3)
    |> validate_length(:counterparty_currency_code, is: 3)
    |> assoc_constraint(:created_by_user)
    |> assoc_constraint(:originator_party)
    |> assoc_constraint(:counterparty_party)
    |> foreign_key_constraint(:source_quote_id)
    |> foreign_key_constraint(:originator_currency_code)
    |> foreign_key_constraint(:counterparty_currency_code)
  end

  def reusable_changeset(quote, attrs) do
    quote
    |> cast(attrs, [
      :originator_currency_code,
      :counterparty_currency_code,
      :spread_basis_points,
      :spot_fx_rate,
      :customer_fx_rate,
      :input_snapshot,
      :calculation_snapshot,
      :expires_at
    ])
    |> put_change(:reusable, true)
    |> update_change(:originator_currency_code, &String.upcase/1)
    |> update_change(:counterparty_currency_code, &String.upcase/1)
    |> validate_required([
      :created_by_user_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :spread_basis_points,
      :spot_fx_rate,
      :customer_fx_rate,
      :input_snapshot,
      :calculation_snapshot,
      :expires_at
    ])
    |> validate_number(:spread_basis_points,
      greater_than_or_equal_to: 0,
      less_than: 10_000
    )
    |> validate_number(:spot_fx_rate, greater_than: 0)
    |> validate_number(:customer_fx_rate, greater_than: 0)
    |> validate_length(:originator_currency_code, is: 3)
    |> validate_length(:counterparty_currency_code, is: 3)
    |> assoc_constraint(:created_by_user)
    |> foreign_key_constraint(:originator_currency_code)
    |> foreign_key_constraint(:counterparty_currency_code)
  end
end
