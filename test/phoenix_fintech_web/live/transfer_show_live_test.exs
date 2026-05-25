defmodule PhoenixFintechWeb.TransferShowLiveTest do
  use PhoenixFintechWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhoenixFintech.{Accounts, Ledger, Parties, Transfers}

  describe "GET /app/transfers/:id" do
    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/app/transfers/test-id")
    end

    test "shows transfer details and status timeline", %{conn: conn} do
      user = user_fixture()
      conn = log_in_conn(conn, user)

      originator = party_fixture("Northstar Imports LLC", "12-3456789")
      counterparty = party_fixture("Maple Payments Ltd", "98-7654321")
      _usd = currency_fixture("USD", "US Dollar")
      _cad = currency_fixture("CAD", "Canadian Dollar")

      {:ok, transfer} =
        Transfers.create_transfer(user.id, %{
          "originator_party_id" => originator.id,
          "counterparty_party_id" => counterparty.id,
          "originator_currency_code" => "usd",
          "counterparty_currency_code" => "cad",
          "amount_in_originator_currency" => "1000.00",
          "fx_quote" => %{
            "provider" => "Manual Desk",
            "provider_quote_reference" => "Q-001",
            "rate" => "1.35"
          },
          "status" => "quoted"
        })

      {:ok, view, _html} = live(conn, ~p"/app/transfers/#{transfer.id}")

      assert has_element?(view, "#transfer-show")
      assert has_element?(view, "#transfer-reference", transfer.id)
      assert has_element?(view, "#transfer-status-badge", "Quoted")
      assert has_element?(view, "#transfer-parties")
      assert has_element?(view, "#transfer-amounts")
      assert has_element?(view, "#fx-quote-details")
      assert has_element?(view, "#transfer-status-timeline")
      assert has_element?(view, "#status-step-draft")
      assert has_element?(view, "#status-step-quoted")
      assert has_element?(view, "#status-step-submitted")
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
    {:ok, currency} = Ledger.create_currency(%{"code" => code, "name" => name})
    currency
  end

  defp log_in_conn(conn, user) do
    token = Accounts.generate_session_token(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
