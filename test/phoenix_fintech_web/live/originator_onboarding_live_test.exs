defmodule PhoenixFintechWeb.OriginatorOnboardingLiveTest do
  use PhoenixFintechWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhoenixFintech.Accounts
  alias PhoenixFintech.Parties

  describe "GET /app/parties/new" do
    test "requires authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/app/parties/new")
    end

    test "onboards an originator through a multistep wizard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_conn(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/parties/new")

      assert has_element?(view, "#originator-onboarding")
      assert has_element?(view, "aside", user.email)
      assert has_element?(view, "#party-step-form")

      view
      |> form("#party-step-form",
        party: %{
          legal_name: "Northstar Imports LLC",
          tax_id: "12-3456789",
          address_line1: "100 Market Street",
          address_line2: "Suite 400",
          locality: "San Francisco",
          region: "CA",
          postal_code: "94105",
          country_code: "US"
        },
        party_government_id: %{type: "ein", country_code: "US", value: "12-3456789"}
      )
      |> render_submit()

      assert has_element?(view, "#representative-step-form")

      view
      |> form("#representative-step-form",
        representative: %{
          legal_name: "Ada Lovelace",
          title: "Chief Financial Officer",
          address_line1: "100 Market Street",
          locality: "San Francisco",
          region: "CA",
          postal_code: "94105",
          country_code: "US"
        },
        representative_government_id: %{type: "ssn", country_code: "US", value: "111-22-3333"}
      )
      |> render_submit()

      assert has_element?(view, "#originator-review")

      view
      |> element("#create-originator-button")
      |> render_click()

      assert_redirected(view, ~p"/app/parties")

      assert party = Parties.get_party_by_tax_id("12-3456789")
      assert party.legal_name == "Northstar Imports LLC"

      {:ok, index_view, _html} = live(conn, ~p"/app/parties")
      assert has_element?(index_view, "#party-#{party.id}")
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

  defp log_in_conn(conn, user) do
    token = Accounts.generate_session_token(user)

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
