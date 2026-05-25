defmodule PhoenixFintech.Parties do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Parties.{ComplianceDocument, GovernmentID, Party, PartyMember}
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Storage.MockS3

  def list_parties do
    Repo.all(from p in Party, order_by: [desc: p.inserted_at])
  end

  def list_parties_onboarded_by_user(user_id) do
    Repo.all(
      from p in Party,
        left_join: t in assoc(p, :originator_transfers),
        where: p.created_by_user_id == ^user_id or t.created_by_user_id == ^user_id,
        distinct: p.id,
        order_by: [desc: p.inserted_at]
    )
  end

  def get_party_by_tax_id(tax_id), do: Repo.get_by(Party, tax_id: tax_id)

  def get_party_with_details!(id) do
    members_query =
      from m in PartyMember,
        order_by: [asc: m.parent_party_member_id, asc: m.inserted_at],
        preload: [:government_ids]

    docs_query = from d in ComplianceDocument, order_by: [desc: d.inserted_at]

    Party
    |> Repo.get!(id)
    |> Repo.preload([:government_ids, members: members_query, compliance_documents: docs_query])
  end

  def get_party_with_member_tree!(id), do: get_party_with_details!(id)
  def change_party(attrs \\ %{}), do: Party.changeset(%Party{}, attrs)
  def change_representative(attrs \\ %{}), do: PartyMember.form_changeset(%PartyMember{}, attrs)
  def change_government_id(attrs \\ %{}), do: GovernmentID.form_changeset(%GovernmentID{}, attrs)
  def change_party_member(member, attrs \\ %{}), do: PartyMember.changeset(member, attrs)

  def get_member_for_party!(party_id, member_id),
    do: Repo.get_by!(PartyMember, id: member_id, party_id: party_id)

  def create_party_member(party_id, attrs) do
    %PartyMember{party_id: party_id}
    |> PartyMember.changeset(attrs)
    |> Repo.insert()
  end

  def delete_party_member(%PartyMember{} = member), do: Repo.delete(member)

  def set_member_role(%PartyMember{} = member, role, enabled?)
      when role in [:is_legal_rep, :is_ubo] do
    member
    |> PartyMember.changeset(%{role => enabled?})
    |> Repo.update()
  end

  def create_compliance_document(party_id, user_id, attrs, upload_meta, upload_entry) do
    with {:ok, upload_result} <-
           MockS3.upload_file(
             upload_meta.path,
             upload_entry.client_name,
             upload_entry.client_type
           ) do
      %ComplianceDocument{}
      |> ComplianceDocument.changeset(%{
        party_id: party_id,
        uploaded_by_user_id: user_id,
        doc_type: Map.get(attrs, "doc_type", "other"),
        filename: upload_entry.client_name,
        storage_key: upload_result.key,
        storage_url: upload_result.url
      })
      |> Repo.insert()
    end
  end

  def create_originator(attrs), do: create_originator(nil, attrs)

  def create_originator(created_by_user_id, attrs) do
    party_attrs = Map.get(attrs, "party", %{})
    party_government_id_attrs = Map.get(attrs, "party_government_id", %{})
    representative_attrs = Map.get(attrs, "representative", %{})
    representative_government_id_attrs = Map.get(attrs, "representative_government_id", %{})

    Multi.new()
    |> Multi.insert(
      :party,
      Party.changeset(%Party{created_by_user_id: created_by_user_id}, party_attrs)
    )
    |> Multi.insert(:party_government_id, fn %{party: party} ->
      GovernmentID.changeset(%GovernmentID{party_id: party.id}, party_government_id_attrs)
    end)
    |> maybe_insert_representative(representative_attrs)
    |> maybe_insert_representative_government_id(representative_government_id_attrs)
    |> Repo.transaction()
    |> case do
      {:ok, %{party: party}} -> {:ok, party}
      {:error, step, changeset, changes} -> {:error, step, changeset, changes}
    end
  end

  defp maybe_insert_representative(multi, representative_attrs) do
    if present_attrs?(representative_attrs) do
      Multi.insert(multi, :representative, fn %{party: party} ->
        representative_attrs =
          representative_attrs
          |> Map.put("type", Map.get(representative_attrs, "type", "individual"))
          |> Map.put("is_legal_rep", true)
          |> Map.put("is_ubo", true)

        PartyMember.changeset(%PartyMember{party_id: party.id}, representative_attrs)
      end)
    else
      multi
    end
  end

  defp maybe_insert_representative_government_id(multi, representative_government_id_attrs) do
    if present_attrs?(representative_government_id_attrs) do
      Multi.insert(multi, :representative_government_id, fn changes ->
        case Map.get(changes, :representative) do
          %PartyMember{} = representative ->
            GovernmentID.changeset(
              %GovernmentID{party_member_id: representative.id},
              representative_government_id_attrs
            )

          _missing_representative ->
            GovernmentID.changeset(
              %GovernmentID{},
              representative_government_id_attrs
            )
            |> Ecto.Changeset.add_error(:party_member_id, "can't be blank")
        end
      end)
    else
      multi
    end
  end

  defp present_attrs?(attrs) do
    attrs
    |> Map.drop(["type", "country_code"])
    |> Enum.any?(fn {_key, value} -> value not in [nil, ""] end)
  end
end
