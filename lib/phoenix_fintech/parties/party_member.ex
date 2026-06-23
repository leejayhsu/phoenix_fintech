defmodule PhoenixFintech.Parties.PartyMember do
  use Ecto.Schema

  @type t :: %__MODULE__{}
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
      :country_code
    ])
    |> normalize_country_code()
    |> validate_required([:party_id, :legal_name, :type, :country_code])
    |> validate_individual_title()
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
      :country_code
    ])
    |> normalize_country_code()
    |> validate_required([:legal_name, :type, :country_code])
    |> validate_individual_title()
    |> validate_length(:legal_name, max: 160)
    |> validate_length(:country_code, is: 2)
  end

  defp validate_individual_title(changeset) do
    if get_field(changeset, :type) == :individual do
      validate_required(changeset, [:title])
    else
      changeset
    end
  end

  defp normalize_country_code(changeset) do
    update_change(changeset, :country_code, &String.upcase/1)
  end
end
