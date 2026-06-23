defmodule PhoenixFintech.Accounts do
  import Ecto.Query, warn: false
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Accounts.{User, UserToken}

  @type attrs :: %{optional(String.t() | atom()) => term()}
  @type user_id :: Ecto.UUID.t()
  @type token :: binary()

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  @spec get_user!(user_id()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @spec register_user(attrs()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs), do: %User{} |> User.registration_changeset(attrs) |> Repo.insert()

  @spec change_user_registration(attrs()) :: Ecto.Changeset.t()
  def change_user_registration(attrs \\ %{}), do: User.registration_changeset(%User{}, attrs)

  @spec authenticate_user(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_credentials}
  def authenticate_user(email, password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: {:ok, user}, else: {:error, :invalid_credentials}
  end

  @spec change_user_profile(User.t(), attrs()) :: Ecto.Changeset.t()
  def change_user_profile(user, attrs \\ %{}), do: User.profile_changeset(user, attrs)

  @spec update_user_profile(User.t(), attrs()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_profile(user, attrs), do: user |> User.profile_changeset(attrs) |> Repo.update()

  @spec change_user_password(User.t(), attrs()) :: Ecto.Changeset.t()
  def change_user_password(user, attrs \\ %{}), do: User.password_changeset(user, attrs)

  @spec update_user_password(User.t(), attrs()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, attrs),
    do: user |> User.password_changeset(attrs) |> Repo.update()

  @spec generate_session_token(User.t()) :: token()
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

  @spec get_user_by_session_token(token()) :: User.t() | nil
  def get_user_by_session_token(token) do
    query =
      from ut in UserToken,
        join: u in assoc(ut, :user),
        where:
          ut.context == "session" and ut.token == ^token and ut.expires_at > ^DateTime.utc_now(),
        select: u

    Repo.one(query)
  end

  @spec delete_session_token(token()) :: {non_neg_integer(), nil | [term()]}
  def delete_session_token(token),
    do: Repo.delete_all(from ut in UserToken, where: ut.token == ^token)
end
