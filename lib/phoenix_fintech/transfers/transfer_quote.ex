defmodule PhoenixFintech.Transfers.TransferQuote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfer_quotes" do
    field :originator_currency_code, :string
    field :counterparty_currency_code, :string
    field :amount_in_originator_currency, :decimal
    field :amount_in_counterparty_currency, :decimal
    field :input_snapshot, :map
    field :calculation_snapshot, :map
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :created_by_user, PhoenixFintech.Accounts.User
    belongs_to :originator_party, PhoenixFintech.Parties.Party
    belongs_to :counterparty_party, PhoenixFintech.Parties.Party

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
      :input_snapshot,
      :calculation_snapshot,
      :expires_at,
      :accepted_at
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
      :input_snapshot,
      :calculation_snapshot
    ])
    |> validate_number(:amount_in_originator_currency, greater_than: 0)
    |> validate_number(:amount_in_counterparty_currency, greater_than: 0)
    |> validate_length(:originator_currency_code, is: 3)
    |> validate_length(:counterparty_currency_code, is: 3)
    |> assoc_constraint(:created_by_user)
    |> assoc_constraint(:originator_party)
    |> assoc_constraint(:counterparty_party)
    |> foreign_key_constraint(:originator_currency_code)
    |> foreign_key_constraint(:counterparty_currency_code)
  end
end
