defmodule PhoenixFintech.Transfers.Disbursement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["pending", "initiated", "settled", "failed"]

  schema "disbursements" do
    field :amount, :decimal
    field :currency_code, :string
    field :status, :string, default: "pending"

    belongs_to :transfer, PhoenixFintech.Transfers.Transfer
    belongs_to :destination_party, PhoenixFintech.Parties.Party

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(disbursement, attrs) do
    disbursement
    |> cast(attrs, [
      :transfer_id,
      :destination_party_id,
      :currency_code,
      :amount,
      :status
    ])
    |> validate_required([
      :transfer_id,
      :destination_party_id,
      :currency_code,
      :amount,
      :status
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency_code, is: 3)
    |> update_change(:currency_code, &String.upcase/1)
    |> assoc_constraint(:transfer)
    |> assoc_constraint(:destination_party)
    |> foreign_key_constraint(:currency_code)
  end
end
