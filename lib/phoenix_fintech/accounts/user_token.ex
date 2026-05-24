defmodule PhoenixFintech.Accounts.UserToken do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :expires_at, :utc_datetime
    belongs_to :user, PhoenixFintech.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
