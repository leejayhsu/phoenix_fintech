defmodule PhoenixFintechWeb.UserSessionController do
  use PhoenixFintechWeb, :controller
  import Phoenix.Component, only: [to_form: 2]

  alias PhoenixFintech.Accounts
  alias PhoenixFintechWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, form: to_form(%{"email" => "", "password" => ""}, as: :user))
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, form: to_form(%{"email" => email}, as: :user))
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> redirect(to: ~p"/users/log_in")
  end
end
