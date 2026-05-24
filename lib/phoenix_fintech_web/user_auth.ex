defmodule PhoenixFintechWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias PhoenixFintech.Accounts

  def fetch_current_user(conn, _opts) do
    user =
      with token when is_binary(token) <- get_session(conn, :user_token) do
        Accounts.get_user_by_session_token(token)
      end

    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Please log in to continue.")
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  def log_in_user(conn, user) do
    token = Accounts.generate_session_token(user)

    conn
    |> configure_session(renew: true)
    |> put_session(:user_token, token)
    |> put_flash(:info, "Welcome back, #{user.name}!")
  end

  def log_out_user(conn) do
    if token = get_session(conn, :user_token), do: Accounts.delete_session_token(token)

    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Signed out successfully.")
  end
end
