defmodule PhoenixFintech.Parties do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Compliance

  alias PhoenixFintech.Parties.{
    ComplianceDocument,
    GovernmentID,
    Party,
    PartyEvent,
    PartyMember,
    PartyStateMachine
  }

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
    |> Repo.preload([
      :government_ids,
      :compliance_review,
      :originator_compliance_review,
      members: members_query,
      compliance_documents: docs_query,
      events:
        from(e in PartyEvent,
          order_by: [asc: e.occurred_at, asc: e.inserted_at],
          preload: [:actor_user]
        )
    ])
  end

  def get_party_with_member_tree!(id), do: get_party_with_details!(id)
  def change_party(attrs \\ %{}), do: Party.changeset(%Party{}, attrs)
  def change_representative(attrs \\ %{}), do: PartyMember.form_changeset(%PartyMember{}, attrs)
  def change_government_id(attrs \\ %{}), do: GovernmentID.form_changeset(%GovernmentID{}, attrs)
  def change_party_member(member, attrs \\ %{}), do: PartyMember.changeset(member, attrs)

  def update_party(%Party{} = party, attrs) do
    party
    |> Party.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns the set of statuses a party can move to from `status`.
  """
  def allowed_targets(status) do
    Map.get(PartyStateMachine.transitions(), status, [])
  end

  defp allowed_transition?(status, target) do
    target in allowed_targets(status)
  end

  @doc """
  Moves a party to the next status in its lifecycle.

  `metadata` is an arbitrary map (typically containing `actor_user_id` and
  optional `notes`) that is passed through to the persistence layer.
  """
  def transition_party(%Party{} = party, next_status, metadata \\ %{}) do
    party = Repo.preload(party, [])

    if allowed_transition?(party.status, next_status) do
      Machinery.transition_to(party, PartyStateMachine, next_status, metadata)
      |> case do
        {:ok, party} -> {:ok, get_party_with_details!(party.id)}
        {:error, reason} -> {:error, :transition, reason, %{}}
      end
    else
      {:error, :transition, "cannot transition from #{party.status} to #{next_status}", %{}}
    end
  end

  @doc """
  Persists a party status transition. Invoked by `PartyStateMachine.persist/3`.
  """
  def persist_party_transition!(%Party{} = party, next_status, metadata) do
    metadata = normalize_metadata(metadata)
    from_status = party.status

    Multi.new()
    |> Multi.update(:party, Party.changeset(party, %{status: next_status}))
    |> Multi.insert(:event, fn %{party: party} ->
      party_event_changeset(party, from_status, next_status, metadata)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{party: party}} ->
        party

      {:error, step, reason, _changes} ->
        raise "party transition failed at #{step}: #{inspect(reason)}"
    end
  end

  @doc """
  Lists the event log for a party, oldest first.
  """
  def list_party_events(party_id) do
    Repo.all(
      from e in PartyEvent,
        where: e.party_id == ^party_id,
        order_by: [asc: e.occurred_at, asc: e.inserted_at],
        preload: [:actor_user]
    )
  end

  @doc """
  Builds the changeset for a party event without persisting it. Used to
  compose party transitions into larger transactions.
  """
  def build_party_event_changeset(party, from_status, to_status, metadata) do
    PartyEvent.changeset(%PartyEvent{}, %{
      party_id: party.id,
      actor_user_id: Map.get(metadata, :actor_user_id),
      event_type: Map.get(metadata, :event_type, "#{from_status || "none"}_to_#{to_status}"),
      from_status: from_status,
      to_status: to_status,
      metadata: metadata |> Map.drop([:actor_user_id, :event_type]) |> snapshot(),
      occurred_at: DateTime.utc_now(:second)
    })
  end

  @doc """
  Builds a changeset that grants a party originator eligibility by flipping
  `can_originate` to `true`.

  `can_originate` is set programmatically (never via user input), so it is
  applied with `Ecto.Changeset.change/2` rather than going through the
  party's public changeset. This is **not** a state-machine transition: the
  party's `status` is left untouched and the change is instead recorded as
  a `PartyEvent` with `event_type: "originator_status_granted"` (composed
  into the caller's transaction via `Parties.build_party_event_changeset/4`).
  """
  def build_originator_eligibility_changeset(%Party{} = party) do
    party
    |> Ecto.Changeset.change(can_originate: true)
  end

  defp party_event_changeset(party, from_status, to_status, metadata) do
    build_party_event_changeset(party, from_status, to_status, metadata)
  end

  defp snapshot(value) when is_struct(value, Decimal), do: Decimal.to_string(value, :normal)
  defp snapshot(value) when is_atom(value), do: Atom.to_string(value)

  defp snapshot(value) when is_list(value) do
    Enum.map(value, &snapshot/1)
  end

  defp snapshot(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {snapshot_key(key), snapshot(value)} end)
  end

  defp snapshot(value), do: value

  defp snapshot_key(key) when is_atom(key), do: Atom.to_string(key)
  defp snapshot_key(key), do: key

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: %{}

  def create_party_government_id(party_id, attrs) do
    %GovernmentID{party_id: party_id}
    |> GovernmentID.changeset(attrs)
    |> Repo.insert()
  end

  def get_member_for_party!(party_id, member_id),
    do: Repo.get_by!(PartyMember, id: member_id, party_id: party_id)

  def create_party_member(party_id, attrs) do
    {government_id_attrs, member_attrs} = Map.pop(attrs, "government_id", %{})

    Multi.new()
    |> Multi.insert(
      :member,
      PartyMember.changeset(%PartyMember{party_id: party_id}, member_attrs)
    )
    |> Multi.insert(:government_id, fn %{member: member} ->
      GovernmentID.changeset(%GovernmentID{party_member_id: member.id}, government_id_attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member}} -> {:ok, member}
      {:error, step, changeset, _changes} -> {:error, step, changeset}
    end
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
    |> maybe_insert_party_government_id(party_government_id_attrs)
    |> maybe_insert_representative(representative_attrs)
    |> maybe_insert_representative_government_id(representative_government_id_attrs)
    |> Multi.insert(:compliance_review, fn %{party: party} ->
      Compliance.change_review(%{"party_id" => party.id, "status" => "created"})
    end)
    |> Multi.insert(:event, fn %{party: party} ->
      party_event_changeset(party, nil, "created", %{
        actor_user_id: created_by_user_id,
        event_type: "created"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{party: party}} -> {:ok, party}
      {:error, step, changeset, changes} -> {:error, step, changeset, changes}
    end
  end

  defp maybe_insert_party_government_id(multi, party_government_id_attrs) do
    if present_attrs?(party_government_id_attrs) do
      Multi.insert(multi, :party_government_id, fn %{party: party} ->
        GovernmentID.changeset(%GovernmentID{party_id: party.id}, party_government_id_attrs)
      end)
    else
      multi
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
