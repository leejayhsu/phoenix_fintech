defmodule PhoenixFintech.LedgerTest do
  use PhoenixFintech.DataCase, async: true

  alias PhoenixFintech.Ledger

  test "create currency uppercases" do
    assert {:ok, c} = Ledger.create_currency(%{"code" => "usd", "name" => "US Dollar", "minor_unit" => 2})
    assert c.code == "USD"
    assert {:error, cs} = Ledger.create_currency(%{"code" => "US", "name" => "bad", "minor_unit" => 2})
    assert %{code: _} = errors_on(cs)
  end
end
