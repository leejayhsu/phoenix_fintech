defmodule PhoenixFintech.Transfers.Deposit do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["pending", "received", "failed"]

  schema "deposits" do
    field :amount, :decimal
    field :currency_code, :string
    field :status, :string, default: "pending"

    belongs_to :transfer, PhoenixFintech.Transfers.Transfer
    belongs_to :source_party, PhoenixFintech.Parties.Party

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(deposit, attrs) do
    deposit
    |> cast(attrs, [:transfer_id, :source_party_id, :currency_code, :amount, :status])
    |> validate_required([:transfer_id, :source_party_id, :currency_code, :amount, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_length(:currency_code, is: 3)
    |> update_change(:currency_code, &String.upcase/1)
    |> assoc_constraint(:transfer)
    |> assoc_constraint(:source_party)
    |> foreign_key_constraint(:currency_code)
  end
end
