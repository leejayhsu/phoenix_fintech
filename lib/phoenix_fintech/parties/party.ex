defmodule PhoenixFintech.Parties.Party do
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixFintech.Parties.{ComplianceDocument, GovernmentID, PartyMember}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "parties" do
    field :tax_id, :string
    field :legal_name, :string
    field :address_line1, :string
    field :address_line2, :string
    field :locality, :string
    field :region, :string
    field :postal_code, :string
    field :country_code, :string

    belongs_to :created_by_user, PhoenixFintech.Accounts.User

    has_many :members, PartyMember
    has_many :government_ids, GovernmentID
    has_many :compliance_documents, ComplianceDocument

    has_many :originator_transfers, PhoenixFintech.Transfers.Transfer,
      foreign_key: :originator_party_id

    timestamps(type: :utc_datetime)
  end

  def changeset(party, attrs) do
    party
    |> cast(attrs, [
      :tax_id,
      :legal_name,
      :address_line1,
      :address_line2,
      :locality,
      :region,
      :postal_code,
      :country_code
    ])
    |> normalize_country_code()
    |> validate_required([:legal_name])
    |> validate_length(:tax_id, max: 80)
    |> validate_length(:legal_name, max: 160)
    |> validate_length(:country_code, is: 2)
    |> unique_constraint(:tax_id)
  end

  defp normalize_country_code(changeset) do
    update_change(changeset, :country_code, &String.upcase/1)
  end
end
