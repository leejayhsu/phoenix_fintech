defmodule PhoenixFintechWeb.UserSettingsController do
  use PhoenixFintechWeb, :controller

  alias PhoenixFintech.Accounts

  def edit(conn, _params) do
    user = conn.assigns.current_user

    render(conn, :edit,
      user: user,
      profile_form: to_form(Accounts.change_user_profile(user), as: :profile),
      password_form: to_form(Accounts.change_user_password(user), as: :password)
    )
  end

  def update_profile(conn, %{"profile" => profile_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_profile(user, profile_params) do
      {:ok, _user} ->
        conn |> put_flash(:info, "Profile updated.") |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit,
          user: user,
          profile_form: to_form(changeset, as: :profile),
          password_form: to_form(Accounts.change_user_password(user), as: :password)
        )
    end
  end

  def update_password(conn, %{"password" => password_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password_params) do
      {:ok, _user} ->
        conn |> put_flash(:info, "Password updated.") |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit,
          user: user,
          profile_form: to_form(Accounts.change_user_profile(user), as: :profile),
          password_form: to_form(changeset, as: :password)
        )
    end
  end
end
