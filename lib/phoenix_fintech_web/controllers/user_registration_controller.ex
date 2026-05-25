defmodule PhoenixFintechWeb.UserRegistrationController do
  use PhoenixFintechWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias PhoenixFintech.Accounts
  alias PhoenixFintechWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, form: to_form(Accounts.change_user_registration(), as: :user))
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Account created. Welcome, #{user.name}!")
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: to_form(changeset, as: :user))
    end
  end
end
