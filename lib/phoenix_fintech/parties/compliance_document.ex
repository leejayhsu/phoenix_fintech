defmodule PhoenixFintech.Parties.ComplianceDocument do
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixFintech.Accounts.User
  alias PhoenixFintech.Parties.Party

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "party_compliance_documents" do
    belongs_to :party, Party
    belongs_to :uploaded_by_user, User

    field :doc_type, :string
    field :filename, :string
    field :storage_key, :string
    field :storage_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:party_id, :uploaded_by_user_id, :doc_type, :filename, :storage_key, :storage_url])
    |> validate_required([:party_id, :doc_type, :filename, :storage_key, :storage_url])
    |> foreign_key_constraint(:party_id)
    |> foreign_key_constraint(:uploaded_by_user_id)
  end
end
