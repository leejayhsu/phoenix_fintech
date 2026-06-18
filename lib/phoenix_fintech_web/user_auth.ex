defmodule PhoenixFintechWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias PhoenixFintech.Accounts
  alias PhoenixFintech.Notifications

  use PhoenixFintechWeb, :verified_routes

  def fetch_current_user(conn, _opts) do
    user =
      with token when is_binary(token) <- get_session(conn, :user_token) do
        Accounts.get_user_by_session_token(token)
      end

    conn
    |> assign(:current_user, user)
    |> assign(:current_scope, current_scope(user))
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    user =
      with token when is_binary(token) <- session["user_token"] do
        Accounts.get_user_by_session_token(token)
      end

    {:cont,
     Phoenix.Component.assign(socket,
       current_user: user,
       current_scope: current_scope(user)
     )}
  end

  def on_mount(:require_admin, _params, _session, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.is_admin do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/app")}
    end
  end

  def on_mount(:assign_notifications_unread_count, _params, _session, socket) do
    count =
      case socket.assigns[:current_user] do
        %{id: user_id} -> Notifications.unread_count(user_id)
        _ -> 0
      end

    {:cont, Phoenix.Component.assign(socket, notifications_unread_count: count)}
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

  def require_admin_user(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns.current_user.is_admin do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access that page.")
      |> redirect(to: ~p"/app")
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

  defp current_scope(nil), do: nil
  defp current_scope(user), do: %{user: user}
end
