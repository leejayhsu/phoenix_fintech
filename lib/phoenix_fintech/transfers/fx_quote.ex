defmodule PhoenixFintech.Transfers.FXQuote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transfer_fx_quotes" do
    field :provider, :string
    field :provider_quote_reference, :string
    field :base_currency_code, :string
    field :quote_currency_code, :string
    field :rate, :decimal
    field :expires_at, :utc_datetime
    field :quoted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(fx_quote, attrs) do
    fx_quote
    |> cast(attrs, [
      :provider,
      :provider_quote_reference,
      :base_currency_code,
      :quote_currency_code,
      :rate,
      :expires_at,
      :quoted_at
    ])
    |> update_change(:base_currency_code, &String.upcase/1)
    |> update_change(:quote_currency_code, &String.upcase/1)
    |> validate_required([
      :provider,
      :base_currency_code,
      :quote_currency_code,
      :rate,
      :quoted_at
    ])
    |> validate_length(:base_currency_code, is: 3)
    |> validate_length(:quote_currency_code, is: 3)
    |> validate_number(:rate, greater_than: 0)
    |> unique_constraint(:provider_quote_reference)
    |> foreign_key_constraint(:base_currency_code)
    |> foreign_key_constraint(:quote_currency_code)
  end
end
