defmodule PhoenixFintech.TransfersQuoteTest do
  use PhoenixFintech.DataCase, async: true

  alias PhoenixFintech.{Accounts, Ledger, Parties, Transfers}
  alias PhoenixFintech.Transfers.{Transfer, TransferQuote}

  describe "quote_transfer/2" do
    test "persists immutable input and calculation snapshots" do
      user = user_fixture()
      originator = party_fixture("Northstar Imports LLC", "12-3456789")
      counterparty = party_fixture("Maple Payments Ltd", "98-7654321")
      currency_fixture("USD", "US Dollar")
      currency_fixture("CAD", "Canadian Dollar")

      assert {:ok, %TransferQuote{} = quote} =
               Transfers.quote_transfer(user.id, quote_attrs(originator, counterparty))

      assert quote.created_by_user_id == user.id
      assert quote.originator_party_id == originator.id
      assert quote.counterparty_party_id == counterparty.id
      assert quote.originator_currency_code == "USD"
      assert quote.counterparty_currency_code == "CAD"
      assert quote.amount_in_originator_currency == Decimal.new("1000.00")
      assert quote.amount_in_counterparty_currency == Decimal.new("1350.00")
      assert quote.input_snapshot["amount_in_originator_currency"] == "1000.00"
      assert quote.calculation_snapshot["facts"]["fx_rate"] == "1.35"

      assert quote.calculation_snapshot["lines"] |> Enum.map(& &1["code"]) == [
               "fx_rate",
               "transaction_fee",
               "fx_fee",
               "discount",
               "platform_fee"
             ]
    end

    test "requote creates a distinct quote from the stored input snapshot" do
      user = user_fixture()
      originator = party_fixture("Northstar Imports LLC", "12-3456789")
      counterparty = party_fixture("Maple Payments Ltd", "98-7654321")
      currency_fixture("USD", "US Dollar")
      currency_fixture("CAD", "Canadian Dollar")

      {:ok, quote} = Transfers.quote_transfer(user.id, quote_attrs(originator, counterparty))

      assert {:ok, %TransferQuote{} = requote} =
               Transfers.requote_transfer_quote(user.id, quote.id)

      assert requote.id != quote.id
      assert requote.input_snapshot == quote.input_snapshot
      assert requote.calculation_snapshot == quote.calculation_snapshot
    end

    test "creates a transfer from a stored quote" do
      user = user_fixture()
      originator = party_fixture("Northstar Imports LLC", "12-3456789")
      counterparty = party_fixture("Maple Payments Ltd", "98-7654321")
      currency_fixture("USD", "US Dollar")
      currency_fixture("CAD", "Canadian Dollar")

      {:ok, quote} = Transfers.quote_transfer(user.id, quote_attrs(originator, counterparty))

      assert {:ok, %Transfer{} = transfer} =
               Transfers.create_transfer_from_quote(user.id, quote.id, %{"status" => "quoted"})

      assert transfer.transfer_quote_id == quote.id
      assert transfer.transfer_quote.id == quote.id
      assert transfer.amount_in_counterparty_currency == Decimal.new("1350.00")
      assert transfer.status == :quoted
    end
  end

  defp quote_attrs(originator, counterparty) do
    %{
      "originator_party_id" => originator.id,
      "counterparty_party_id" => counterparty.id,
      "originator_currency_code" => "usd",
      "counterparty_currency_code" => "cad",
      "amount_in_originator_currency" => "1000.00",
      "fx_rate" => "1.35"
    }
  end

  defp user_fixture do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Grace Hopper",
        "email" => "grace-#{System.unique_integer([:positive])}@example.com",
        "password" => "supersecure"
      })

    user
  end

  defp party_fixture(legal_name, tax_id) do
    {:ok, party} =
      Parties.create_originator(%{
        "party" => %{
          "legal_name" => legal_name,
          "tax_id" => tax_id,
          "address_line1" => "100 Market Street",
          "locality" => "San Francisco",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "party_government_id" => %{"type" => "ein", "country_code" => "US", "value" => tax_id},
        "representative" => %{},
        "representative_government_id" => %{}
      })

    party
  end

  defp currency_fixture(code, name) do
    {:ok, currency} = Ledger.create_currency(%{"code" => code, "name" => name, "minor_unit" => 2})
    currency
  end
end
