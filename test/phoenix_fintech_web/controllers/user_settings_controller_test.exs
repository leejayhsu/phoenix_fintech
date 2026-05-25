defmodule PhoenixFintechWeb.UserSettingsControllerTest do
  use PhoenixFintechWeb.ConnCase, async: true

  describe "GET /users/settings" do
    test "renders the authenticated app sidebar", %{conn: conn} do
      conn =
        post(conn, ~p"/users/sign_up", %{
          "user" => %{
            "name" => "Ada Lovelace",
            "email" => "ada-settings@example.com",
            "password" => "supersecure"
          }
        })

      conn = get(conn, ~p"/users/settings")
      html = html_response(conn, 200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("aside a[href=\"/app\"]") |> Enum.any?()
      assert document |> LazyHTML.query("aside a[href=\"/users/settings\"]") |> Enum.any?()
    end
  end
end
