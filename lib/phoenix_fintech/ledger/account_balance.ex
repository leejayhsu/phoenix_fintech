defmodule PhoenixFintech.Ledger.AccountBalance do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ledger_account_balances" do
    field :currency_code, :string
    field :pending_balance, :decimal, default: Decimal.new(0)
    field :available_balance, :decimal, default: Decimal.new(0)
    field :posted_balance, :decimal, default: Decimal.new(0)
    belongs_to :account, PhoenixFintech.Ledger.Account, foreign_key: :ledger_account_id
    timestamps(type: :utc_datetime)
  end

  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [
      :ledger_account_id,
      :currency_code,
      :pending_balance,
      :available_balance,
      :posted_balance
    ])
    |> update_change(:currency_code, &String.upcase/1)
    |> validate_required([:ledger_account_id, :currency_code])
    |> validate_length(:currency_code, is: 3)
    |> unique_constraint([:ledger_account_id, :currency_code])
  end
end
