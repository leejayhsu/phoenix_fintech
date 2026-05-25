defmodule PhoenixFintechWeb.UserRegistrationControllerTest do
  use PhoenixFintechWeb.ConnCase, async: true

  alias PhoenixFintech.Accounts

  describe "GET /users/sign_up" do
    test "renders the signup form", %{conn: conn} do
      conn = get(conn, ~p"/users/sign_up")
      html = html_response(conn, 200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("#signup-form") |> Enum.any?()
      assert document |> LazyHTML.query("input#user_name") |> Enum.any?()
      assert document |> LazyHTML.query("input#user_email") |> Enum.any?()
      assert document |> LazyHTML.query("input#user_password") |> Enum.any?()
    end
  end

  describe "POST /users/sign_up" do
    test "creates and signs in the user", %{conn: conn} do
      params = %{
        "user" => %{
          "name" => "Ada Lovelace",
          "email" => "ada@example.com",
          "password" => "supersecure"
        }
      }

      conn = post(conn, ~p"/users/sign_up", params)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert Accounts.get_user_by_email("ada@example.com")
    end

    test "renders errors for invalid signup details", %{conn: conn} do
      conn =
        post(conn, ~p"/users/sign_up", %{
          "user" => %{"name" => "A", "email" => "bad", "password" => "short"}
        })

      html = html_response(conn, 422)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("#signup-form") |> Enum.any?()
      assert [] = get_resp_header(conn, "location")
    end
  end
end
