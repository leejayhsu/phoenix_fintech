defmodule PhoenixFintech.Parties.GovernmentID do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  alias PhoenixFintech.Parties.{Party, PartyMember}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "government_ids" do
    belongs_to :party, Party
    belongs_to :party_member, PartyMember

    field :type, Ecto.Enum, values: [:ein, :ssn, :passport, :national_id]
    field :country_code, :string
    field :value, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  def changeset(government_id, attrs) do
    government_id
    |> cast(attrs, [:party_id, :party_member_id, :type, :country_code, :value])
    |> normalize_country_code()
    |> validate_required([:type, :country_code, :value])
    |> validate_length(:country_code, is: 2)
    |> validate_owner()
    |> foreign_key_constraint(:party_id)
    |> foreign_key_constraint(:party_member_id)
    |> check_constraint(:owner, name: :government_ids_exactly_one_owner)
  end

  def form_changeset(government_id, attrs \\ %{}) do
    government_id
    |> cast(attrs, [:type, :country_code, :value])
    |> normalize_country_code()
    |> validate_required([:type, :country_code, :value])
    |> validate_length(:country_code, is: 2)
  end

  defp validate_owner(changeset) do
    owners =
      [:party_id, :party_member_id]
      |> Enum.count(&(get_field(changeset, &1) not in [nil, ""]))

    if owners == 1 do
      changeset
    else
      add_error(changeset, :owner, "must reference exactly one owner")
    end
  end

  defp normalize_country_code(changeset) do
    update_change(changeset, :country_code, &String.upcase/1)
  end
end
