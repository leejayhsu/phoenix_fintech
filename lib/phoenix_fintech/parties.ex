defmodule PhoenixFintech.Parties do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Parties.{GovernmentID, Party, PartyMember}
  alias PhoenixFintech.Repo

  def list_parties do
    Repo.all(from p in Party, order_by: [desc: p.inserted_at])
  end

  def get_party_by_tax_id(tax_id), do: Repo.get_by(Party, tax_id: tax_id)

  def get_party_with_member_tree!(id) do
    members_query =
      from m in PartyMember,
        order_by: [asc: m.parent_party_member_id, asc: m.inserted_at],
        preload: [:government_ids]

    Party
    |> Repo.get!(id)
    |> Repo.preload([:government_ids, members: members_query])
  end

  def change_party(attrs \\ %{}), do: Party.changeset(%Party{}, attrs)

  def change_representative(attrs \\ %{}), do: PartyMember.form_changeset(%PartyMember{}, attrs)

  def change_government_id(attrs \\ %{}), do: GovernmentID.form_changeset(%GovernmentID{}, attrs)

  def create_originator(attrs) do
    party_attrs = Map.get(attrs, "party", %{})
    party_government_id_attrs = Map.get(attrs, "party_government_id", %{})
    representative_attrs = Map.get(attrs, "representative", %{})
    representative_government_id_attrs = Map.get(attrs, "representative_government_id", %{})

    Multi.new()
    |> Multi.insert(:party, Party.changeset(%Party{}, party_attrs))
    |> Multi.insert(:party_government_id, fn %{party: party} ->
      GovernmentID.changeset(%GovernmentID{party_id: party.id}, party_government_id_attrs)
    end)
    |> Multi.insert(:representative, fn %{party: party} ->
      representative_attrs =
        representative_attrs
        |> Map.put("type", "individual")
        |> Map.put("is_legal_rep", true)
        |> Map.put("is_ubo", true)

      PartyMember.changeset(%PartyMember{party_id: party.id}, representative_attrs)
    end)
    |> Multi.insert(:representative_government_id, fn %{representative: representative} ->
      GovernmentID.changeset(
        %GovernmentID{party_member_id: representative.id},
        representative_government_id_attrs
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{party: party}} -> {:ok, party}
      {:error, step, changeset, changes} -> {:error, step, changeset, changes}
    end
  end
end
