defmodule PhoenixFintech.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :name, :password])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> validate_length(:password, min: 8, max: 72)
    |> put_password_hash()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 80)
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> put_password_hash()
  end

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _), do: false

  defp put_password_hash(changeset) do
    password = get_change(changeset, :password)

    if changeset.valid? and is_binary(password) do
      put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end
end
