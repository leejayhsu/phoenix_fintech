defmodule PhoenixFintechWeb.PartyShowLiveTest do
  use PhoenixFintechWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PhoenixFintech.Accounts
  alias PhoenixFintech.Parties

  test "renders details and allows member mutation", %{conn: conn} do
    user = user_fixture()
    conn = log_in_conn(conn, user)
    party = party_fixture()

    {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

    view |> element("#add-top-level-member-button") |> render_click()

    assert has_element?(view, "#party-details")

    view
    |> form("#party-member-form",
      party_member: %{
        legal_name: "Holding Co",
        type: "business",
        title: "Owner",
        address_line1: "10 Main",
        locality: "Austin",
        region: "TX",
        postal_code: "78701",
        country_code: "US"
      }
    )
    |> render_submit()

    assert has_element?(view, "#members")
  end

  test "renders party members as a vertical LiveFlow tree", %{conn: conn} do
    user = user_fixture()
    conn = log_in_conn(conn, user)
    party = party_fixture()

    {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")
    representative = List.first(Parties.get_party_with_details!(party.id).members)

    assert has_element?(view, "#party-member-flow")
    assert has_element?(view, "#party-member-flow-node-party-root")
    assert has_element?(view, "#party-member-flow-node-#{representative.id}")
    assert has_element?(view, "#party-member-flow-node-#{representative.id}.member-node")
    refute has_element?(view, "#member-children-#{representative.id}")
  end

  test "accepts LiveFlow node measurement events", %{conn: conn} do
    user = user_fixture()
    conn = log_in_conn(conn, user)
    party = party_fixture()
    representative = List.first(Parties.get_party_with_details!(party.id).members)

    {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

    render_hook(view, "lf:node_change", %{
      "changes" => [
        %{"id" => representative.id, "type" => "dimensions", "width" => 272, "height" => 156}
      ]
    })

    assert has_element?(view, "#party-member-flow-node-#{representative.id}.member-node")
  end

  test "opens member modal for top-level and child members", %{conn: conn} do
    user = user_fixture()
    conn = log_in_conn(conn, user)
    party = party_fixture()

    {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

    view |> element("#add-top-level-member-button") |> render_click()

    assert has_element?(view, "#party-member-modal")
    assert has_element?(view, "#party-member-form")
    assert has_element?(view, "#party_member_parent_party_member_id option[selected][value='']")

    representative = List.first(Parties.get_party_with_details!(party.id).members)

    view |> element("#add-child-member-#{representative.id}") |> render_click()

    assert has_element?(
             view,
             "#party_member_parent_party_member_id option[selected][value='#{representative.id}']"
           )
  end

  test "creates and renders a child member under its parent", %{conn: conn} do
    user = user_fixture()
    conn = log_in_conn(conn, user)
    party = party_fixture()
    representative = List.first(Parties.get_party_with_details!(party.id).members)

    {:ok, view, _html} = live(conn, ~p"/app/parties/#{party.id}")

    view |> element("#add-child-member-#{representative.id}") |> render_click()

    view
    |> form("#party-member-form",
      party_member: %{
        parent_party_member_id: representative.id,
        legal_name: "Child Holding LLC",
        type: "business",
        title: "Subsidiary",
        address_line1: "200 Market",
        locality: "Austin",
        region: "TX",
        postal_code: "78701",
        country_code: "US"
      }
    )
    |> render_submit()

    assert has_element?(
             view,
             "#party-member-flow .member-node",
             "Child Holding LLC"
           )

    refute has_element?(view, "#party-member-modal")
  end

  defp party_fixture do
    {:ok, party} =
      Parties.create_originator(%{
        "party" => %{
          "legal_name" => "Acme",
          "tax_id" => "99-#{System.unique_integer([:positive])}",
          "address_line1" => "100 Market Street",
          "locality" => "SF",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "party_government_id" => %{"type" => "ein", "country_code" => "US", "value" => "1"},
        "representative" => %{
          "legal_name" => "Ada",
          "address_line1" => "100 Market Street",
          "locality" => "SF",
          "region" => "CA",
          "postal_code" => "94105",
          "country_code" => "US"
        },
        "representative_government_id" => %{
          "type" => "ssn",
          "country_code" => "US",
          "value" => "2"
        }
      })

    party
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
