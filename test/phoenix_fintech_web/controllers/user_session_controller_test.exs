defmodule PhoenixFintechWeb.UserSessionControllerTest do
  use PhoenixFintechWeb.ConnCase, async: true

  describe "GET /users/log_in" do
    test "links to the signup page", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")
      html = html_response(conn, 200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("a#signup-link[href=\"/users/sign_up\"]") |> Enum.any?()
    end
  end
end
