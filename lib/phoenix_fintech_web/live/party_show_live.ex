defmodule PhoenixFintechWeb.PartyShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties
  alias PhoenixFintech.Parties.PartyMember

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    party = Parties.get_party_with_details!(id)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:party, party)
      |> assign(:page_title, party.legal_name)
      |> assign_current_user()
      |> assign_member_form()
      |> assign(:member_parent_options, member_parent_options(party.members))
      |> assign_doc_form()
      |> allow_upload(:compliance_document, accept: ~w(.pdf .png .jpg .jpeg), max_entries: 1)
      |> stream(:members, party.members)
      |> stream(:documents, party.compliance_documents)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_member", %{"party_member" => member_params}, socket) do
    attrs = Map.put(member_params, "type", Map.get(member_params, "type", "individual"))

    case Parties.create_party_member(socket.assigns.party.id, attrs) do
      {:ok, member} ->
        members = [member | stream_members(socket)]

        {:noreply,
         socket
         |> stream_insert(:members, member)
         |> assign(:member_parent_options, member_parent_options(members))
         |> assign_member_form()}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :member_form,
           to_form(%{changeset | action: :validate}, as: :party_member)
         )}
    end
  end

  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Parties.get_member_for_party!(socket.assigns.party.id, id)
    {:ok, _} = Parties.delete_party_member(member)

    members = Enum.reject(stream_members(socket), &(&1.id == member.id))

    {:noreply,
     socket
     |> stream_delete(:members, member)
     |> assign(:member_parent_options, member_parent_options(members))}
  end

  def handle_event("toggle_role", %{"id" => id, "role" => role}, socket) do
    member = Parties.get_member_for_party!(socket.assigns.party.id, id)
    field = if role == "legal_rep", do: :is_legal_rep, else: :is_ubo
    enabled = not Map.get(member, field)
    {:ok, member} = Parties.set_member_role(member, field, enabled)
    {:noreply, stream_insert(socket, :members, member)}
  end

  def handle_event("upload_document", %{"document" => document_params}, socket) do
    user_id = if socket.assigns.current_user, do: socket.assigns.current_user.id, else: nil

    consume_uploaded_entries(socket, :compliance_document, fn meta, entry ->
      case Parties.create_compliance_document(
             socket.assigns.party.id,
             user_id,
             document_params,
             meta,
             entry
           ) do
        {:ok, document} -> {:ok, document}
        {:error, _} = error -> error
      end
    end)
    |> case do
      [document] -> {:noreply, socket |> stream_insert(:documents, document) |> assign_doc_form()}
      _ -> {:noreply, put_flash(socket, :error, "Document upload failed")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section class="mx-auto max-w-6xl space-y-6" id="party-details">
        <h1 class="text-3xl font-semibold">{@party.legal_name}</h1>
        <p class="text-sm text-zinc-600">Tax ID: {@party.tax_id}</p>

        <div class="grid gap-6 lg:grid-cols-2">
          <div class="rounded-xl border p-5">
            <h2 class="mb-4 text-lg font-semibold">Party members</h2>
            <.form
              for={@member_form}
              id="party-member-form"
              phx-submit="create_member"
              class="grid gap-3"
            >
              <.input field={@member_form[:legal_name]} label="Legal name" />
              <.input
                field={@member_form[:type]}
                type="select"
                label="Type"
                options={[{"Individual", "individual"}, {"Business", "business"}]}
              />
              <.input
                field={@member_form[:parent_party_member_id]}
                type="select"
                label="Parent member"
                options={@member_parent_options}
              />
              <.input field={@member_form[:title]} label="Title" />
              <.input field={@member_form[:address_line1]} label="Address line 1" />
              <.input field={@member_form[:locality]} label="City" />
              <.input field={@member_form[:region]} label="Region" />
              <.input field={@member_form[:postal_code]} label="Postal code" />
              <.input field={@member_form[:country_code]} label="Country code" />
              <.button id="create-member-button" type="submit">Add member</.button>
            </.form>

            <div id="members" phx-update="stream" class="mt-4 space-y-3">
              <div
                :for={{dom_id, member} <- @streams.members}
                id={dom_id}
                class="rounded-lg border p-3"
              >
                <p class="font-medium">{member.legal_name || "Unnamed member"}</p>
                <p class="text-xs text-zinc-600">{member.type} · {member.title || "-"}</p>
                <p :if={member.parent_party_member_id} class="text-xs text-zinc-500">
                  Child of: {member.parent_party_member_id}
                </p>
                <div class="mt-2 flex gap-2">
                  <button
                    phx-click="toggle_role"
                    phx-value-id={member.id}
                    phx-value-role="legal_rep"
                    class="rounded-md border px-2 py-1 text-xs"
                  >
                    Legal rep: {member.is_legal_rep}
                  </button>
                  <button
                    phx-click="toggle_role"
                    phx-value-id={member.id}
                    phx-value-role="ubo"
                    class="rounded-md border px-2 py-1 text-xs"
                  >
                    Beneficiary: {member.is_ubo}
                  </button>
                  <button
                    phx-click="delete_member"
                    phx-value-id={member.id}
                    class="rounded-md border border-red-300 px-2 py-1 text-xs text-red-700"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div class="rounded-xl border p-5">
            <h2 class="mb-4 text-lg font-semibold">Compliance documents</h2>
            <.form
              for={@document_form}
              id="party-document-form"
              phx-submit="upload_document"
              class="space-y-3"
            >
              <.input
                field={@document_form[:doc_type]}
                type="select"
                label="Document type"
                options={[
                  {"Certificate of incorporation", "incorporation_certificate"},
                  {"Ownership structure", "ownership_structure"},
                  {"Other", "other"}
                ]}
              />
              <.live_file_input
                upload={@uploads.compliance_document}
                class="block w-full rounded-lg border p-2"
              />
              <.button id="upload-document-button" type="submit">Upload document</.button>
            </.form>

            <div id="documents" phx-update="stream" class="mt-4 space-y-2">
              <div
                :for={{dom_id, doc} <- @streams.documents}
                id={dom_id}
                class="rounded-md border p-2 text-sm"
              >
                <a href={doc.storage_url} class="font-medium text-emerald-700 hover:underline">
                  {doc.filename}
                </a>
                <p class="text-xs text-zinc-500">{doc.doc_type}</p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp assign_member_form(socket) do
    member_attrs = %{
      "type" => "individual",
      "country_code" => "US",
      "parent_party_member_id" => ""
    }

    changeset =
      Parties.change_party_member(%PartyMember{party_id: socket.assigns.party.id}, member_attrs)

    assign(socket, :member_form, to_form(changeset, as: :party_member))
  end

  defp assign_doc_form(socket),
    do: assign(socket, :document_form, to_form(%{"doc_type" => "other"}, as: :document))

  defp stream_members(socket) do
    socket.assigns.streams.members.inserts
    |> Enum.map(fn {_id, member, _at, _limit} -> member end)
  end

  defp member_parent_options(members) do
    base_option = [{"No parent (top-level)", ""}]

    nested_options =
      members
      |> build_member_children()
      |> flatten_member_tree()
      |> Enum.map(fn {member, depth} ->
        indent = String.duplicate("— ", depth)
        label = "#{indent}#{member.legal_name || "Unnamed member"}"
        {label, member.id}
      end)

    base_option ++ nested_options
  end

  defp build_member_children(members) do
    Enum.group_by(members, & &1.parent_party_member_id)
  end

  defp flatten_member_tree(children_by_parent) do
    walk_member_tree(children_by_parent, nil, 0)
  end

  defp walk_member_tree(children_by_parent, parent_id, depth) do
    children = Map.get(children_by_parent, parent_id, [])

    Enum.flat_map(children, fn member ->
      [{member, depth} | walk_member_tree(children_by_parent, member.id, depth + 1)]
    end)
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
end
