defmodule PhoenixFintech.Parties.PartyMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixFintech.Parties.{GovernmentID, Party, PartyMember}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "party_members" do
    belongs_to :party, Party
    belongs_to :parent, PartyMember, foreign_key: :parent_party_member_id

    field :legal_name, :string
    field :type, Ecto.Enum, values: [:business, :individual], default: :individual
    field :title, :string
    field :is_legal_rep, :boolean, default: false
    field :is_ubo, :boolean, default: false
    field :address_line1, :string
    field :address_line2, :string
    field :locality, :string
    field :region, :string
    field :postal_code, :string
    field :country_code, :string

    has_many :government_ids, GovernmentID

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [
      :parent_party_member_id,
      :legal_name,
      :type,
      :title,
      :is_legal_rep,
      :is_ubo,
      :address_line1,
      :address_line2,
      :locality,
      :region,
      :postal_code,
      :country_code
    ])
    |> normalize_country_code()
    |> validate_required([:party_id, :type])
    |> validate_length(:legal_name, max: 160)
    |> validate_length(:country_code, is: 2)
    |> foreign_key_constraint(:party_id)
    |> foreign_key_constraint(:parent_party_member_id)
  end

  def form_changeset(member, attrs \\ %{}) do
    member
    |> cast(attrs, [
      :legal_name,
      :type,
      :parent_party_member_id,
      :title,
      :address_line1,
      :address_line2,
      :locality,
      :region,
      :postal_code,
      :country_code
    ])
    |> normalize_country_code()
    |> validate_length(:legal_name, max: 160)
    |> validate_length(:country_code, is: 2)
  end

  defp normalize_country_code(changeset) do
    update_change(changeset, :country_code, &String.upcase/1)
  end
end
