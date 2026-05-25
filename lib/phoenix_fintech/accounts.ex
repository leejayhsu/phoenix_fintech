defmodule PhoenixFintech.Accounts do
  import Ecto.Query, warn: false
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Accounts.{User, UserToken}

  def get_user_by_email(email), do: Repo.get_by(User, email: email)
  def get_user!(id), do: Repo.get!(User, id)

  def register_user(attrs), do: %User{} |> User.registration_changeset(attrs) |> Repo.insert()

  def change_user_registration(attrs \\ %{}), do: User.registration_changeset(%User{}, attrs)

  def authenticate_user(email, password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: {:ok, user}, else: {:error, :invalid_credentials}
  end

  def change_user_profile(user, attrs \\ %{}), do: User.profile_changeset(user, attrs)
  def update_user_profile(user, attrs), do: user |> User.profile_changeset(attrs) |> Repo.update()

  def change_user_password(user, attrs \\ %{}), do: User.password_changeset(user, attrs)

  def update_user_password(user, attrs),
    do: user |> User.password_changeset(attrs) |> Repo.update()

  def generate_session_token(user) do
    token = :crypto.strong_rand_bytes(32)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(60 * 60 * 24 * 14, :second)
      |> DateTime.truncate(:second)

    %UserToken{}
    |> Ecto.Changeset.change(%{
      token: token,
      context: "session",
      user_id: user.id,
      expires_at: expires_at
    })
    |> Repo.insert!()

    token
  end

  def get_user_by_session_token(token) do
    query =
      from ut in UserToken,
        join: u in assoc(ut, :user),
        where:
          ut.context == "session" and ut.token == ^token and ut.expires_at > ^DateTime.utc_now(),
        select: u

    Repo.one(query)
  end

  def delete_session_token(token),
    do: Repo.delete_all(from ut in UserToken, where: ut.token == ^token)
end
