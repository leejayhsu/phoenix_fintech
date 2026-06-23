defmodule PhoenixFintech.Ledger.Currency do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:code, :string, autogenerate: false}

  schema "currencies" do
    field :name, :string
    field :minor_unit, :integer
    timestamps(type: :utc_datetime)
  end

  def changeset(currency, attrs) do
    currency
    |> cast(attrs, [:code, :name, :minor_unit])
    |> update_change(:code, &String.upcase/1)
    |> validate_required([:code, :name, :minor_unit])
    |> validate_length(:code, is: 3)
    |> validate_number(:minor_unit, greater_than_or_equal_to: 0, less_than_or_equal_to: 6)
  end
end
