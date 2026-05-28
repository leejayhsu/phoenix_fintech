defmodule PhoenixFintechWeb.TransferNewLiveTest do
  use PhoenixFintechWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhoenixFintech.{Accounts, Ledger, Parties, Transfers}

  describe "GET /app/transfers/new" do
    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} =
               live(conn, ~p"/app/transfers/new")
    end

    test "creates transfer through details and quote steps", %{conn: conn} do
      user = user_fixture()
      conn = log_in_conn(conn, user)

      originator = party_fixture("Northstar Imports LLC", "12-3456789")
      counterparty = party_fixture("Maple Payments Ltd", "98-7654321")
      _usd = currency_fixture("USD", "US Dollar")
      _cad = currency_fixture("CAD", "Canadian Dollar")

      {:ok, view, _html} = live(conn, ~p"/app/transfers/new")

      assert has_element?(view, "#transfer-details-form")
      assert has_element?(view, "#continue-to-quote-button")

      view
      |> element("#transfer-details-form")
      |> render_submit(%{
        "transfer" => %{
          "originator_party_id" => originator.id,
          "counterparty_party_id" => counterparty.id,
          "originator_currency_code" => "USD",
          "counterparty_currency_code" => "CAD",
          "amount_in_originator_currency" => "1000.00",
          "amount_in_counterparty_currency" => ""
        }
      })

      assert has_element?(view, "#transfer-quote-form")

      view
      |> element("#transfer-quote-form")
      |> render_submit(%{
        "transfer" => %{
          "originator_party_id" => originator.id,
          "counterparty_party_id" => counterparty.id,
          "originator_currency_code" => "USD",
          "counterparty_currency_code" => "CAD",
          "amount_in_originator_currency" => "1000.00",
          "amount_in_counterparty_currency" => ""
        },
        "quote" => %{"fx_rate" => "1.35"}
      })

      path = assert_redirected(view)

      [transfer] = Transfers.list_transfers_for_user(user.id)
      assert path == ~p"/app/transfers/#{transfer.id}"
      assert transfer.originator_party_id == originator.id
      assert transfer.counterparty_party_id == counterparty.id
      assert Decimal.eq?(transfer.amount_in_originator_currency, Decimal.new("1000.00"))
      assert Decimal.eq?(transfer.amount_in_counterparty_currency, Decimal.new("1350.0000"))
      assert transfer.transfer_quote_id
    end
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
        "representative" => %{
          "legal_name" => "Representative",
          "title" => "CFO",
          "address_line1" => "100 Market Street",
          "locality" => "San Francisco",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "representative_government_id" => %{
          "type" => "ssn",
          "country_code" => "US",
          "value" => "111-22-3333"
        }
      })

    party
  end

  defp currency_fixture(code, name) do
    {:ok, currency} = Ledger.create_currency(%{"code" => code, "name" => name, "minor_unit" => 2})
    currency
  end

  defp log_in_conn(conn, user) do
    token = Accounts.generate_session_token(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
