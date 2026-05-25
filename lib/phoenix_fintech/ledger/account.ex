defmodule PhoenixFintech.Ledger.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ledger_accounts" do
    field :type, Ecto.Enum, values: [:nostro, :user, :system]
    field :name, :string
    field :is_negative_balance_allowed, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:type, :name, :is_negative_balance_allowed])
    |> validate_required([:type, :name])
  end
end
