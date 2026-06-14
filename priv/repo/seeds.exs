# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PhoenixFintech.Repo.insert!(%PhoenixFintech.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias PhoenixFintech.Ledger.Currency
alias PhoenixFintech.Repo

utc_now = DateTime.utc_now(:second)

currencies = [
  %{code: "USD", name: "United States Dollar", minor_unit: 2},
  %{code: "EUR", name: "Euro", minor_unit: 2},
  %{code: "GBP", name: "British Pound", minor_unit: 2},
  %{code: "JPY", name: "Japanese Yen", minor_unit: 0},
  %{code: "CNY", name: "Chinese Yuan", minor_unit: 2},
  %{code: "BRL", name: "Brazilian Real", minor_unit: 2},
  %{code: "MXN", name: "Mexican Peso", minor_unit: 2}
]

for currency <- currencies do
  attrs =
    currency
    |> Map.put(:inserted_at, utc_now)
    |> Map.put(:updated_at, utc_now)

  Repo.insert!(
    struct(Currency, attrs),
    on_conflict: {:replace, [:name, :minor_unit, :updated_at]},
    conflict_target: :code
  )
end
