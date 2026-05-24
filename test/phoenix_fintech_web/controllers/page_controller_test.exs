defmodule PhoenixFintechWeb.PageControllerTest do
  use PhoenixFintechWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert document |> LazyHTML.query_by_id("home-page") |> Enum.any?()
  end
end
