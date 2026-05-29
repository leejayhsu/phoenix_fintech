defmodule PhoenixFintechWeb.PartyShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties
  alias PhoenixFintech.Parties.PartyMember
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Changes.{EdgeChange, NodeChange}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    party = Parties.get_party_with_details!(id)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:party, party)
      |> assign(:page_title, party.legal_name)
      |> assign_current_user()
      |> assign(:members, party.members)
      |> assign(:active_tab, socket.assigns[:live_action] || :overview)
      |> assign_member_flow(party, party.members)
      |> assign(:member_modal_open?, false)
      |> assign(:member_modal_title, "Add member")
      |> assign_member_form()
      |> assign(:member_parent_options, member_parent_options(party.members))
      |> assign_doc_form()
      |> allow_upload(:compliance_document, accept: ~w(.pdf .png .jpg .jpeg), max_entries: 1)
      |> stream(:documents, party.compliance_documents)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :active_tab, socket.assigns.live_action || :overview)}
  end

  @impl true
  def handle_event("create_member", %{"party_member" => member_params}, socket) do
    attrs = Map.put(member_params, "type", Map.get(member_params, "type", "individual"))

    case Parties.create_party_member(socket.assigns.party.id, attrs) do
      {:ok, member} ->
        members = [member | socket.assigns.members]

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign_member_flow(socket.assigns.party, members)
         |> assign(:member_parent_options, member_parent_options(members))
         |> assign(:member_modal_open?, false)
         |> assign_member_form()}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:member_modal_open?, true)
         |> assign(
           :member_form,
           to_form(%{changeset | action: :validate}, as: :party_member)
         )}
    end
  end

  def handle_event("open_member_modal", %{"parent-id" => parent_id}, socket) do
    title = if parent_id == "", do: "Add top-level member", else: "Add child member"

    {:noreply,
     socket
     |> assign(:member_modal_open?, true)
     |> assign(:member_modal_title, title)
     |> assign_member_form(%{"parent_party_member_id" => parent_id})}
  end

  def handle_event("close_member_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:member_modal_open?, false)
     |> assign_member_form()}
  end

  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Parties.get_member_for_party!(socket.assigns.party.id, id)
    {:ok, _} = Parties.delete_party_member(member)

    members = Enum.reject(socket.assigns.members, &(&1.id == member.id))

    {:noreply,
     socket
     |> assign(:members, members)
     |> assign_member_flow(socket.assigns.party, members)
     |> assign(:member_parent_options, member_parent_options(members))}
  end

  def handle_event("toggle_role", %{"id" => id, "role" => role}, socket) do
    member = Parties.get_member_for_party!(socket.assigns.party.id, id)
    field = if role == "legal_rep", do: :is_legal_rep, else: :is_ubo
    enabled = not Map.get(member, field)
    {:ok, member} = Parties.set_member_role(member, field, enabled)

    members =
      Enum.map(socket.assigns.members, fn existing ->
        if existing.id == member.id, do: member, else: existing
      end)

    {:noreply,
     socket
     |> assign(:members, members)
     |> assign_member_flow(socket.assigns.party, members)}
  end

  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow = NodeChange.apply_changes(socket.assigns.member_flow, changes)

    {:noreply, assign(socket, :member_flow, flow)}
  end

  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    flow = EdgeChange.apply_changes(socket.assigns.member_flow, changes)

    {:noreply, assign(socket, :member_flow, flow)}
  end

  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.member_flow, params)

    {:noreply, assign(socket, :member_flow, flow)}
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
      <section class="mx-auto max-w-6xl space-y-6 px-4 sm:px-6 lg:px-8" id="party-details">
        <div class="space-y-4 border-b border-zinc-200 pb-5 dark:border-zinc-800">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-emerald-700 dark:text-emerald-300">
              Party profile
            </p>
            <h1 class="mt-1 text-3xl font-semibold text-zinc-950 dark:text-zinc-50">
              {@party.legal_name}
            </h1>
            <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-400">Tax ID: {@party.tax_id}</p>
          </div>

          <.party_tabs party={@party} active_tab={@active_tab} />
        </div>

        <.overview_panel :if={@active_tab == :overview} party={@party} members={@members} />
        <.members_panel :if={@active_tab == :members} members={@members} member_flow={@member_flow} />
        <.documents_panel
          :if={@active_tab == :documents}
          document_form={@document_form}
          uploads={@uploads}
          streams={@streams}
        />
      </section>

      <div :if={@member_modal_open?} id="party-member-modal" class="fixed inset-0 z-50">
        <button
          id="party-member-modal-backdrop"
          type="button"
          phx-click="close_member_modal"
          class="absolute inset-0 bg-zinc-950/50 backdrop-blur-sm transition"
          aria-label="Close member form"
        >
        </button>
        <div class="absolute left-1/2 top-1/2 max-h-[88vh] w-[min(92vw,34rem)] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-xl border border-zinc-200 bg-white p-5 shadow-2xl dark:border-zinc-800 dark:bg-zinc-900">
          <div class="mb-4 flex items-center justify-between gap-4">
            <h3 class="text-lg font-semibold">{@member_modal_title}</h3>
            <button
              id="close-member-modal-button"
              type="button"
              phx-click="close_member_modal"
              class="rounded-lg p-2 text-zinc-500 transition hover:bg-zinc-100 hover:text-zinc-900 dark:hover:bg-zinc-800 dark:hover:text-white"
              aria-label="Close member form"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

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
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :party, :map, required: true
  attr :active_tab, :atom, required: true

  defp party_tabs(assigns) do
    ~H"""
    <nav class="tabs tabs-box w-fit bg-zinc-100 p-1 dark:bg-zinc-900" aria-label="Party sections">
      <.link
        id="party-overview-tab"
        navigate={~p"/app/parties/#{@party.id}"}
        class={[
          "tab h-9 px-4 text-sm transition",
          @active_tab == :overview && "tab-active"
        ]}
      >
        Overview
      </.link>
      <.link
        id="party-members-tab"
        navigate={~p"/app/parties/#{@party.id}/members"}
        class={[
          "tab h-9 px-4 text-sm transition",
          @active_tab == :members && "tab-active"
        ]}
      >
        Members
      </.link>
      <.link
        id="party-documents-tab"
        navigate={~p"/app/parties/#{@party.id}/documents"}
        class={[
          "tab h-9 px-4 text-sm transition",
          @active_tab == :documents && "tab-active"
        ]}
      >
        Documents
      </.link>
    </nav>
    """
  end

  attr :party, :map, required: true
  attr :members, :list, required: true

  defp overview_panel(assigns) do
    ~H"""
    <div id="party-overview" class="space-y-6">
      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <.summary_card
          label="Onboarding status"
          value="In review"
          detail="EDD checklist 72% complete"
        />
        <.summary_card label="Risk rating" value="Moderate" detail="Updated after ownership review" />
        <.summary_card label="Relationship manager" value="Maya Chen" detail="Fintech growth desk" />
        <.summary_card
          label="Expected monthly volume"
          value="$480K"
          detail="Across card and ACH rails"
        />
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
        <section class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
          <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">Business profile</h2>
          <dl class="mt-5 grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Industry</dt>
              <dd class="mt-1 text-sm font-medium text-zinc-900 dark:text-zinc-100">
                Embedded payments platform
              </dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide text-zinc-500">
                Operating regions
              </dt>
              <dd class="mt-1 text-sm font-medium text-zinc-900 dark:text-zinc-100">
                United States, Canada
              </dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide text-zinc-500">
                Primary currency
              </dt>
              <dd class="mt-1 text-sm font-medium text-zinc-900 dark:text-zinc-100">USD</dd>
            </div>
          </dl>
        </section>

        <section class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
          <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">Recent activity</h2>
          <div class="mt-4 space-y-3">
            <.activity_item
              title="Representative verified"
              detail="Identity match completed this morning"
            />
            <.activity_item
              title="Ownership document requested"
              detail="Awaiting updated cap table from operations"
            />
            <.activity_item
              title="Risk review queued"
              detail="Compliance review scheduled for Friday"
            />
          </div>
        </section>
      </div>

      <div class="grid gap-4 md:grid-cols-2">
        <.overview_link_card
          id="party-members-overview-link"
          href={~p"/app/parties/#{@party.id}/members"}
          title="Party members"
          count={length(@members)}
          detail="Review ownership, representatives, and beneficial owners."
        />
        <.overview_link_card
          id="party-documents-overview-link"
          href={~p"/app/parties/#{@party.id}/documents"}
          title="Compliance documents"
          count={length(@party.compliance_documents)}
          detail="Upload and inspect onboarding evidence."
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true

  defp summary_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md dark:border-zinc-800 dark:bg-zinc-950">
      <p class="text-xs font-semibold uppercase tracking-wide text-zinc-500">{@label}</p>
      <p class="mt-2 text-xl font-semibold text-zinc-950 dark:text-zinc-50">{@value}</p>
      <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{@detail}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :detail, :string, required: true

  defp activity_item(assigns) do
    ~H"""
    <div class="rounded-md border border-zinc-200 p-3 dark:border-zinc-800">
      <p class="text-sm font-medium text-zinc-950 dark:text-zinc-50">{@title}</p>
      <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{@detail}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :detail, :string, required: true

  defp overview_link_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@href}
      class="group rounded-lg border border-zinc-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-md dark:border-zinc-800 dark:bg-zinc-950 dark:hover:border-emerald-700"
    >
      <div class="flex items-center justify-between gap-4">
        <div>
          <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">{@title}</h2>
          <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{@detail}</p>
        </div>
        <span class="rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300">
          {@count}
        </span>
      </div>
    </.link>
    """
  end

  attr :members, :list, required: true
  attr :member_flow, :map, required: true

  defp members_panel(assigns) do
    ~H"""
    <div
      id="party-members-panel"
      class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950"
    >
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">Party members</h2>
          <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
            Map representatives, ownership, and subsidiaries in the member tree.
          </p>
        </div>
        <.button
          id="add-top-level-member-button"
          type="button"
          phx-click="open_member_modal"
          phx-value-parent-id=""
        >
          <.icon name="hero-plus" class="size-4" /> Add top-level
        </.button>
      </div>

      <div id="members" class="mt-5">
        <div
          :if={@members == []}
          class="rounded-lg border border-dashed border-zinc-300 p-4 text-sm text-zinc-500 dark:border-zinc-700 dark:text-zinc-400"
        >
          No party members yet.
        </div>
        <div
          :if={@members != []}
          class="overflow-hidden rounded-lg border border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-950"
          style={"height: #{flow_height(@members)}"}
        >
          <.live_component
            module={LiveFlow.Components.Flow}
            id="party-member-flow"
            flow={@member_flow}
            node_types={%{party: &party_flow_node/1, member: &member_flow_node/1}}
            opts={
              %{
                background: :dots,
                controls: true,
                fit_view_on_init: true,
                nodes_draggable: false,
                nodes_connectable: false,
                elements_selectable: false,
                pan_on_drag: true,
                zoom_on_scroll: true
              }
            }
          />
        </div>
      </div>
    </div>
    """
  end

  attr :document_form, :map, required: true
  attr :uploads, :map, required: true
  attr :streams, :map, required: true

  defp documents_panel(assigns) do
    ~H"""
    <div id="party-documents-panel" class="grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
      <section class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
        <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">Upload document</h2>
        <.form
          for={@document_form}
          id="party-document-form"
          phx-submit="upload_document"
          class="mt-4 space-y-3"
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
            class="block w-full rounded-lg border border-zinc-200 p-2 text-sm transition file:mr-3 file:rounded-md file:border-0 file:bg-emerald-50 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-emerald-700 hover:border-emerald-300 dark:border-zinc-700 dark:file:bg-emerald-950 dark:file:text-emerald-300"
          />
          <.button id="upload-document-button" type="submit">Upload document</.button>
        </.form>
      </section>

      <section class="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-950">
        <h2 class="text-lg font-semibold text-zinc-950 dark:text-zinc-50">
          Compliance documents
        </h2>
        <div id="documents" phx-update="stream" class="mt-4 space-y-2">
          <div
            id="documents-empty"
            class="hidden rounded-lg border border-dashed border-zinc-300 p-4 text-sm text-zinc-500 only:block dark:border-zinc-700 dark:text-zinc-400"
          >
            No compliance documents uploaded yet.
          </div>
          <div
            :for={{dom_id, doc} <- @streams.documents}
            id={dom_id}
            class="rounded-md border border-zinc-200 p-3 text-sm transition hover:border-emerald-300 hover:bg-emerald-50/50 dark:border-zinc-800 dark:hover:border-emerald-700 dark:hover:bg-emerald-950/20"
          >
            <a href={doc.storage_url} class="font-medium text-emerald-700 hover:underline">
              {doc.filename}
            </a>
            <p class="mt-1 text-xs text-zinc-500">{doc.doc_type}</p>
          </div>
        </div>
      </section>
    </div>
    """
  end

  attr :node, :map, required: true

  defp party_flow_node(assigns) do
    ~H"""
    <div
      id="party-member-flow-node-party-root"
      class="min-w-48 rounded-lg border border-zinc-200 bg-white px-4 py-3 text-center shadow-sm dark:border-zinc-800 dark:bg-zinc-900"
    >
      <p class="text-xs font-semibold uppercase tracking-wide text-emerald-700 dark:text-emerald-300">
        Party
      </p>
      <p class="mt-1 font-semibold text-zinc-900 dark:text-zinc-50">
        {@node.data.party.legal_name}
      </p>
      <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
        Tax ID: {@node.data.party.tax_id}
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp member_flow_node(assigns) do
    ~H"""
    <div
      id={"party-member-flow-node-#{@node.id}"}
      class="member-node min-w-60 rounded-lg border border-zinc-200 bg-white p-3 shadow-sm transition hover:border-emerald-300 hover:shadow-md dark:border-zinc-800 dark:bg-zinc-900 dark:hover:border-emerald-700"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="font-medium">{@node.data.member.legal_name || "Unnamed member"}</p>
          <p class="text-xs text-zinc-600 dark:text-zinc-400">
            {@node.data.member.type} · {@node.data.member.title || "-"}
          </p>
        </div>
        <button
          id={"add-child-member-#{@node.id}"}
          type="button"
          phx-click="open_member_modal"
          phx-value-parent-id={@node.id}
          class="inline-flex size-8 shrink-0 items-center justify-center rounded-lg border border-zinc-200 text-zinc-600 transition hover:border-emerald-300 hover:bg-emerald-50 hover:text-emerald-700 dark:border-zinc-700 dark:text-zinc-300 dark:hover:border-emerald-700 dark:hover:bg-emerald-950/40 dark:hover:text-emerald-300"
          aria-label={"Add child member to #{@node.data.member.legal_name || "unnamed member"}"}
        >
          <.icon name="hero-plus" class="size-4" />
        </button>
      </div>

      <div class="mt-2 flex flex-wrap gap-2">
        <button
          phx-click="toggle_role"
          phx-value-id={@node.id}
          phx-value-role="legal_rep"
          class="rounded-md border border-zinc-200 px-2 py-1 text-xs transition hover:bg-zinc-50 dark:border-zinc-700 dark:hover:bg-zinc-800"
        >
          Legal rep: {@node.data.member.is_legal_rep}
        </button>
        <button
          phx-click="toggle_role"
          phx-value-id={@node.id}
          phx-value-role="ubo"
          class="rounded-md border border-zinc-200 px-2 py-1 text-xs transition hover:bg-zinc-50 dark:border-zinc-700 dark:hover:bg-zinc-800"
        >
          Beneficiary: {@node.data.member.is_ubo}
        </button>
        <button
          phx-click="delete_member"
          phx-value-id={@node.id}
          class="rounded-md border border-red-300 px-2 py-1 text-xs text-red-700 transition hover:bg-red-50 dark:border-red-800 dark:text-red-300 dark:hover:bg-red-950/40"
        >
          Delete
        </button>
      </div>
    </div>
    """
  end

  defp assign_member_flow(socket, party, members),
    do: assign(socket, :member_flow, build_member_flow(party, members))

  defp build_member_flow(party, members) do
    children_by_parent = build_member_children(members)
    level_members = members_by_level(children_by_parent)

    nodes =
      [
        Node.new(
          "party-root",
          %{x: 360, y: 0},
          %{party: party},
          type: :party,
          draggable: false,
          connectable: false,
          selectable: false,
          deletable: false,
          handles: [Handle.source(:bottom, id: "children")]
        )
      ] ++ member_flow_nodes(level_members)

    edges =
      members
      |> Enum.map(fn member ->
        parent_id = member.parent_party_member_id || "party-root"

        Edge.new(
          "member-edge-#{parent_id}-#{member.id}",
          parent_id,
          member.id,
          source_handle: "children",
          target_handle: "parent",
          type: :smoothstep,
          selectable: false,
          deletable: false,
          style: %{"stroke" => "#10b981", "stroke-width" => "2.5px"},
          marker_end: %{type: :arrow, color: "#10b981"}
        )
      end)

    State.new(nodes: nodes, edges: edges)
  end

  defp member_flow_nodes(level_members) do
    Enum.flat_map(level_members, fn {depth, members_at_depth} ->
      total_width = max((length(members_at_depth) - 1) * 300, 0)

      members_at_depth
      |> Enum.with_index()
      |> Enum.map(fn {member, index} ->
        x = 360 - total_width / 2 + index * 300
        y = 150 + depth * 170

        Node.new(
          member.id,
          %{x: x, y: y},
          %{member: member},
          type: :member,
          draggable: false,
          connectable: false,
          selectable: false,
          deletable: false,
          handles: [
            Handle.target(:top, id: "parent"),
            Handle.source(:bottom, id: "children")
          ]
        )
      end)
    end)
  end

  defp members_by_level(children_by_parent) do
    children_by_parent
    |> flatten_member_tree()
    |> Enum.group_by(fn {_member, depth} -> depth end, fn {member, _depth} -> member end)
    |> Enum.sort_by(fn {depth, _members} -> depth end)
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

  defp flow_height(members) do
    max_depth =
      members
      |> build_member_children()
      |> flatten_member_tree()
      |> Enum.map(fn {_member, depth} -> depth end)
      |> Enum.max(fn -> 0 end)

    "#{max(420, 300 + max_depth * 170)}px"
  end

  defp assign_member_form(socket, overrides \\ %{}) do
    member_attrs =
      Map.merge(
        %{
          "type" => "individual",
          "country_code" => "US",
          "parent_party_member_id" => ""
        },
        overrides
      )

    changeset =
      Parties.change_party_member(%PartyMember{party_id: socket.assigns.party.id}, member_attrs)

    assign(socket, :member_form, to_form(changeset, as: :party_member))
  end

  defp assign_doc_form(socket),
    do: assign(socket, :document_form, to_form(%{"doc_type" => "other"}, as: :document))

  defp current_user(%{user: user}), do: user
  defp current_user(_), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
end
