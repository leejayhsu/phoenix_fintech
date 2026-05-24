defmodule PhoenixFintechWeb.PageController do
  use PhoenixFintechWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
