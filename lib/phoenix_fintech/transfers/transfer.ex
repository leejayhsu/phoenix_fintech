defmodule PhoenixFintech.Transfers.Transfer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfers" do
    field :status, :string, default: "created"
    field :originator_currency_code, :string
    field :counterparty_currency_code, :string
    field :amount_in_originator_currency, :decimal
    field :amount_in_counterparty_currency, :decimal

    belongs_to :created_by_user, PhoenixFintech.Accounts.User
    belongs_to :originator_party, PhoenixFintech.Parties.Party
    belongs_to :counterparty_party, PhoenixFintech.Parties.Party
    belongs_to :transfer_quote, PhoenixFintech.Transfers.TransferQuote
    has_many :events, PhoenixFintech.Transfers.TransferEvent

    timestamps(type: :utc_datetime)
  end

  def changeset(transfer, attrs) do
    transfer
    |> cast(attrs, [
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :amount_in_originator_currency,
      :amount_in_counterparty_currency,
      :status,
      :transfer_quote_id
    ])
    |> update_change(:originator_currency_code, &String.upcase/1)
    |> update_change(:counterparty_currency_code, &String.upcase/1)
    |> validate_required([
      :originator_party_id,
      :counterparty_party_id,
      :originator_currency_code,
      :counterparty_currency_code,
      :amount_in_originator_currency,
      :amount_in_counterparty_currency
    ])
    |> validate_number(:amount_in_originator_currency, greater_than: 0)
    |> validate_number(:amount_in_counterparty_currency, greater_than: 0)
    |> validate_length(:originator_currency_code, is: 3)
    |> validate_length(:counterparty_currency_code, is: 3)
    |> validate_different_parties()
    |> assoc_constraint(:originator_party)
    |> assoc_constraint(:counterparty_party)
    |> assoc_constraint(:created_by_user)
    |> assoc_constraint(:transfer_quote)
    |> foreign_key_constraint(:originator_currency_code)
    |> foreign_key_constraint(:counterparty_currency_code)
  end

  defp validate_different_parties(changeset) do
    originator_party_id = get_field(changeset, :originator_party_id)
    counterparty_party_id = get_field(changeset, :counterparty_party_id)

    if not is_nil(originator_party_id) and originator_party_id == counterparty_party_id do
      add_error(changeset, :counterparty_party_id, "must be different from originator party")
    else
      changeset
    end
  end
end
