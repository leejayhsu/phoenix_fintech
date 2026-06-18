defmodule PhoenixFintechWeb.PartyShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties
  alias PhoenixFintech.Parties.PartyMember
  alias LiveFlow.{Edge, Handle, Node, State}

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
      |> assign(:party_government_id_modal_open?, false)
      |> assign_member_form()
      |> assign_party_address_form()
      |> assign_party_government_id_form()
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
  def handle_event(
        "create_member",
        %{"party_member" => member_params, "government_id" => government_id_params},
        socket
      ) do
    attrs = Map.put(member_params, "type", Map.get(member_params, "type", "individual"))
    attrs = Map.put(attrs, "government_id", government_id_params)

    case Parties.create_party_member(socket.assigns.party.id, attrs) do
      {:ok, member} ->
        members = [member | socket.assigns.members]

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign_member_flow(socket.assigns.party, members)
         |> assign(:member_modal_open?, false)
         |> assign_member_form()}

      {:error, :member, changeset} ->
        {:noreply,
         socket
         |> assign(:member_modal_open?, true)
         |> assign(
           :member_form,
           to_form(%{changeset | action: :validate}, as: :party_member)
         )
         |> assign_member_government_id_form(government_id_params)}

      {:error, :government_id, changeset} ->
        {:noreply,
         socket
         |> assign(:member_modal_open?, true)
         |> assign_member_form(member_params)
         |> assign(
           :member_government_id_form,
           to_form(%{changeset | action: :validate}, as: :government_id)
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

  def handle_event("open_party_government_id_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:party_government_id_modal_open?, true)
     |> assign_party_government_id_form()}
  end

  def handle_event("close_party_government_id_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:party_government_id_modal_open?, false)
     |> assign_party_government_id_form()}
  end

  def handle_event("update_party_address", %{"party_address" => address_params}, socket) do
    case Parties.update_party(socket.assigns.party, address_params) do
      {:ok, party} ->
        party = Parties.get_party_with_details!(party.id)

        {:noreply,
         socket
         |> put_flash(:info, "Party address updated.")
         |> assign(:party, party)
         |> assign_member_flow(party, socket.assigns.members)
         |> assign_party_address_form()}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :party_address_form,
           to_form(%{changeset | action: :validate}, as: :party_address)
         )}
    end
  end

  def handle_event(
        "create_party_government_id",
        %{"party_government_id" => government_id_params},
        socket
      ) do
    case Parties.create_party_government_id(socket.assigns.party.id, government_id_params) do
      {:ok, _government_id} ->
        party = Parties.get_party_with_details!(socket.assigns.party.id)

        {:noreply,
         socket
         |> put_flash(:info, "Business government ID added.")
         |> assign(:party, party)
         |> assign_member_flow(party, socket.assigns.members)
         |> assign(:party_government_id_modal_open?, false)
         |> assign_party_government_id_form()}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:party_government_id_modal_open?, true)
         |> assign(
           :party_government_id_form,
           to_form(%{changeset | action: :validate}, as: :party_government_id)
         )}
    end
  end

  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Parties.get_member_for_party!(socket.assigns.party.id, id)
    {:ok, _} = Parties.delete_party_member(member)

    members = Enum.reject(socket.assigns.members, &(&1.id == member.id))

    {:noreply,
     socket
     |> assign(:members, members)
     |> assign_member_flow(socket.assigns.party, members)}
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

  def handle_event("lf:node_change", _params, socket), do: {:noreply, socket}

  def handle_event("lf:edge_change", _params, socket), do: {:noreply, socket}

  def handle_event("lf:selection_change", _params, socket), do: {:noreply, socket}

  def handle_event("lf:drag_start", _params, socket), do: {:noreply, socket}

  def handle_event("lf:drag_move", _params, socket), do: {:noreply, socket}

  def handle_event("lf:drag_stop", _params, socket), do: {:noreply, socket}

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

  def handle_event("validate_document", %{"document" => document_params}, socket) do
    {:noreply, assign_doc_form(socket, document_params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      notifications_unread_count={@notifications_unread_count}
    >
      <section class="mx-auto max-w-6xl space-y-6 px-4 sm:px-6 lg:px-8" id="party-details">
        <div class="space-y-4 border-b border-base-300 pb-5">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-primary">
                Party profile
              </p>
              <h1 class="mt-1 text-3xl font-semibold">
                {@party.legal_name}
              </h1>
            </div>

            <.link
              :if={@party.compliance_review}
              id="party-compliance-review-badge"
              navigate={~p"/admin/compliance_reviews/#{@party.compliance_review.id}"}
              class={compliance_review_badge_classes(@party.compliance_review.status)}
            >
              Compliance: {render_compliance_status(@party.compliance_review.status)}
            </.link>
          </div>

          <.party_tabs party={@party} active_tab={@active_tab} />
        </div>

        <.overview_panel
          :if={@active_tab == :overview}
          party={@party}
          members={@members}
          party_address_form={@party_address_form}
        />
        <.members_panel :if={@active_tab == :members} members={@members} member_flow={@member_flow} />
        <.documents_panel
          :if={@active_tab == :documents}
          document_form={@document_form}
          uploads={@uploads}
          streams={@streams}
        />
      </section>

      <div :if={@member_modal_open?} id="party-member-modal" class="modal modal-open" tabindex="0">
        <button
          id="party-member-modal-backdrop"
          type="button"
          phx-click="close_member_modal"
          class="modal-backdrop"
          aria-label="Close member form"
        >
        </button>
        <div class="modal-box max-h-[88vh] w-[min(92vw,34rem)] max-w-none">
          <div class="mb-4 flex items-center justify-between gap-4">
            <h3 class="text-lg font-semibold">{@member_modal_title}</h3>
            <button
              id="close-member-modal-button"
              type="button"
              phx-click="close_member_modal"
              class="btn btn-ghost btn-sm btn-circle"
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
            <input
              type="hidden"
              name={@member_form[:parent_party_member_id].name}
              value={@member_form[:parent_party_member_id].value || ""}
            />
            <.input field={@member_form[:legal_name]} label="Name or company name" />
            <.input
              field={@member_form[:type]}
              type="select"
              label="Type"
              options={[{"Individual", "individual"}, {"Business", "business"}]}
            />
            <.input field={@member_form[:title]} label="Role within company" />
            <.input
              field={@member_form[:country_code]}
              label="Country of birth/business"
              maxlength="2"
            />
            <div class="divider my-1">Government ID</div>
            <.input
              field={@member_government_id_form[:type]}
              type="select"
              label="Type"
              options={[SSN: "ssn", EIN: "ein", Passport: "passport", "National ID": "national_id"]}
            />
            <.input
              field={@member_government_id_form[:country_code]}
              label="Issuing country"
              maxlength="2"
            />
            <.input field={@member_government_id_form[:value]} label="Value" />
            <.button id="create-member-button" type="submit">Add member</.button>
          </.form>
        </div>
      </div>

      <div
        :if={@party_government_id_modal_open?}
        id="party-government-id-modal"
        class="modal modal-open"
        tabindex="0"
      >
        <button
          id="party-government-id-modal-backdrop"
          type="button"
          phx-click="close_party_government_id_modal"
          class="modal-backdrop"
          aria-label="Close government ID form"
        >
        </button>
        <div class="modal-box w-[min(92vw,28rem)] max-w-none">
          <div class="mb-4 flex items-center justify-between gap-4">
            <h3 class="text-lg font-semibold">Add business government ID</h3>
            <button
              id="close-party-government-id-modal-button"
              type="button"
              phx-click="close_party_government_id_modal"
              class="btn btn-ghost btn-sm btn-circle"
              aria-label="Close government ID form"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <.form
            for={@party_government_id_form}
            id="party-government-id-form"
            phx-submit="create_party_government_id"
            class="grid gap-3"
          >
            <.input
              field={@party_government_id_form[:type]}
              type="select"
              label="Type"
              options={[EIN: "ein", Passport: "passport", "National ID": "national_id"]}
            />
            <.input
              field={@party_government_id_form[:country_code]}
              label="Issuing country"
              maxlength="2"
            />
            <.input field={@party_government_id_form[:value]} label="Value" />
            <div class="modal-action">
              <button
                id="cancel-party-government-id-button"
                type="button"
                phx-click="close_party_government_id_modal"
                class="btn btn-ghost"
              >
                Cancel
              </button>
              <.button id="add-party-government-id-button" type="submit">
                Add government ID
              </.button>
            </div>
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
    <nav class="tabs tabs-box w-fit" aria-label="Party sections">
      <.link
        id="party-overview-tab"
        navigate={~p"/app/parties/#{@party.id}"}
        class={[
          "tab",
          @active_tab == :overview && "tab-active"
        ]}
      >
        Overview
      </.link>
      <.link
        id="party-members-tab"
        navigate={~p"/app/parties/#{@party.id}/members"}
        class={[
          "tab",
          @active_tab == :members && "tab-active"
        ]}
      >
        Members
      </.link>
      <.link
        id="party-documents-tab"
        navigate={~p"/app/parties/#{@party.id}/documents"}
        class={[
          "tab",
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
  attr :party_address_form, :map, required: true

  defp overview_panel(assigns) do
    ~H"""
    <div id="party-overview" class="space-y-6">
      <div class="grid gap-6 lg:grid-cols-2">
        <section class="card card-border bg-base-100">
          <div class="card-body">
            <h2 class="card-title text-lg">Business address</h2>

            <%= if address_present?(@party) do %>
              <div class="mt-4 text-sm leading-6">
                <p>{@party.address_line1}</p>
                <p :if={@party.address_line2 not in [nil, ""]}>{@party.address_line2}</p>
                <p>
                  {[@party.locality, @party.region, @party.postal_code]
                  |> Enum.reject(&(&1 in [nil, ""]))
                  |> Enum.join(", ")}
                </p>
                <p>{@party.country_code}</p>
              </div>
            <% else %>
              <p class="mt-1 text-sm text-base-content/70">
                Add a mailing address when it becomes available.
              </p>
            <% end %>

            <.form
              for={@party_address_form}
              id="party-address-form"
              phx-submit="update_party_address"
              class="mt-4 grid gap-3 sm:grid-cols-2"
            >
              <.input
                field={@party_address_form[:address_line1]}
                label="Address line 1"
                autocomplete="address-line1"
              />
              <.input
                field={@party_address_form[:address_line2]}
                label="Address line 2"
                autocomplete="address-line2"
              />
              <.input
                field={@party_address_form[:locality]}
                label="City"
                autocomplete="address-level2"
              />
              <.input
                field={@party_address_form[:region]}
                label="Region"
                autocomplete="address-level1"
              />
              <.input
                field={@party_address_form[:postal_code]}
                label="Postal code"
                autocomplete="postal-code"
              />
              <.input
                field={@party_address_form[:country_code]}
                label="Country code"
                maxlength="2"
                autocomplete="country"
              />
              <div class="sm:col-span-2">
                <.button id="save-party-address-button" type="submit">Save address</.button>
              </div>
            </.form>
          </div>
        </section>

        <section class="card card-border bg-base-100">
          <div class="card-body">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="card-title text-lg">Business government IDs</h2>
                <p class="mt-1 text-sm text-base-content/70">
                  Store the EIN or other identifiers used for verification.
                </p>
              </div>
              <button
                id="open-party-government-id-modal-button"
                type="button"
                phx-click="open_party_government_id_modal"
                class="btn btn-primary btn-sm shrink-0"
              >
                Add ID
              </button>
            </div>

            <%= if @party.government_ids == [] do %>
              <div class="alert alert-info alert-soft mt-4">
                No business government IDs added yet.
              </div>
            <% else %>
              <ul class="list mt-4 rounded-box border border-base-300 bg-base-200">
                <li :for={government_id <- @party.government_ids} class="list-row">
                  <div class="flex size-10 items-center justify-center rounded-field bg-base-200">
                    <.icon name="hero-identification" class="size-5 text-base-content/60" />
                  </div>
                  <div>
                    <p class="font-medium">{government_id_summary(government_id)}</p>
                    <p class="text-xs text-base-content/60">
                      Added {Calendar.strftime(government_id.inserted_at, "%b %-d, %Y")}
                    </p>
                  </div>
                </li>
              </ul>
            <% end %>
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
      class="card card-border bg-base-100"
    >
      <div class="card-body flex-row items-center justify-between gap-4">
        <div>
          <h2 class="card-title text-lg">{@title}</h2>
          <p class="mt-1 text-sm text-base-content/70">{@detail}</p>
        </div>
        <span class="badge badge-primary badge-lg">
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
      class="card card-border bg-base-100"
    >
      <div class="card-body">
        <div>
          <div>
            <h2 class="card-title text-lg">Party members</h2>
            <p class="mt-1 text-sm text-base-content/70">
              Map representatives, ownership, and subsidiaries in the member tree.
            </p>
          </div>
        </div>

        <div id="members" class="mt-5">
          <div
            class="overflow-hidden rounded-box border border-base-300 bg-base-200"
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
    </div>
    """
  end

  attr :document_form, :map, required: true
  attr :uploads, :map, required: true
  attr :streams, :map, required: true

  defp documents_panel(assigns) do
    ~H"""
    <div id="party-documents-panel" class="grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
      <section class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title text-lg">Upload document</h2>
          <.form
            for={@document_form}
            id="party-document-form"
            phx-change="validate_document"
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
            <div class="flex flex-wrap items-center gap-2">
              <.live_file_input upload={@uploads.compliance_document} class="sr-only" />
              <label for={@uploads.compliance_document.ref} class="btn btn-primary">
                Choose file
              </label>
              <.button id="upload-document-button" type="submit">Upload document</.button>
            </div>
            <div
              :for={entry <- @uploads.compliance_document.entries}
              id={"document-upload-preview-#{entry.ref}"}
              class="flex items-center gap-3 rounded-box border border-base-300 bg-base-200 p-3"
            >
              <.live_img_preview
                :if={image_upload_entry?(entry)}
                entry={entry}
                class="size-16 rounded-field object-cover"
              />
              <div
                :if={!image_upload_entry?(entry)}
                class="flex size-16 items-center justify-center rounded-field bg-base-300"
              >
                <.icon name="hero-document" class="size-7 text-base-content/60" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-medium">{entry.client_name}</p>
                <p class="text-xs text-base-content/60">{entry.progress}% uploaded</p>
              </div>
            </div>
          </.form>
        </div>
      </section>

      <section class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title text-lg">
            Compliance documents
          </h2>
          <div id="documents" phx-update="stream" class="mt-4 space-y-2">
            <div
              id="documents-empty"
              class="alert alert-info alert-soft hidden only:flex"
            >
              No compliance documents uploaded yet.
            </div>
            <div
              :for={{dom_id, doc} <- @streams.documents}
              id={dom_id}
              class="card card-border bg-base-200 text-sm"
            >
              <div class="card-body flex-row items-center gap-3 p-3">
                <img
                  :if={image_document?(doc)}
                  src={doc.storage_url}
                  alt={"#{doc.filename} thumbnail"}
                  class="size-16 rounded-field object-cover"
                />
                <div
                  :if={!image_document?(doc)}
                  class="flex size-16 shrink-0 items-center justify-center rounded-field bg-base-200"
                >
                  <.icon name="hero-document" class="size-7 text-base-content/60" />
                </div>
                <div class="min-w-0">
                  <a href={doc.storage_url} class="link link-primary font-medium">
                    {doc.filename}
                  </a>
                  <p class="mt-1 text-xs text-base-content/60">{doc.doc_type}</p>
                </div>
              </div>
            </div>
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
      class="card card-border min-w-60 bg-base-100"
    >
      <div class="card-body p-3">
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-primary">
              Party
            </p>
            <p class="mt-1 font-semibold">
              {@node.data.party.legal_name}
            </p>
            <p class="mt-1 text-xs text-base-content/60">
              Tax ID: {@node.data.party.tax_id}
            </p>
          </div>
          <button
            id="add-root-party-member"
            type="button"
            phx-click="open_member_modal"
            phx-value-parent-id=""
            class="btn btn-ghost btn-square btn-sm shrink-0"
            aria-label={"Add top-level member to #{@node.data.party.legal_name}"}
          >
            <.icon name="hero-plus" class="size-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp member_flow_node(assigns) do
    ~H"""
    <div
      id={"party-member-flow-node-#{@node.id}"}
      class="member-node card card-border min-w-60 bg-base-100"
    >
      <div class="card-body p-3">
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="font-medium">{@node.data.member.legal_name || "Unnamed member"}</p>
            <p class="text-xs text-base-content/70">
              {@node.data.member.type} · {@node.data.member.title || "-"}
            </p>
          </div>
          <button
            id={"add-child-member-#{@node.id}"}
            type="button"
            phx-click="open_member_modal"
            phx-value-parent-id={@node.id}
            class="btn btn-ghost btn-square btn-sm shrink-0"
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
            class="btn btn-xs btn-soft"
          >
            Legal rep: {@node.data.member.is_legal_rep}
          </button>
          <button
            phx-click="toggle_role"
            phx-value-id={@node.id}
            phx-value-role="ubo"
            class="btn btn-xs btn-soft"
          >
            Beneficiary: {@node.data.member.is_ubo}
          </button>
          <button
            phx-click="delete_member"
            phx-value-id={@node.id}
            class="btn btn-error btn-soft btn-xs"
          >
            Delete
          </button>
        </div>
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
          style: %{"stroke" => "var(--color-success)", "stroke-width" => "2.5px"},
          marker_end: %{type: :arrow, color: "context-stroke"}
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

  defp assign_party_address_form(socket) do
    changeset = Parties.change_party(Map.take(socket.assigns.party, party_address_fields()))

    assign(socket, :party_address_form, to_form(changeset, as: :party_address))
  end

  defp assign_party_government_id_form(socket, attrs \\ %{}) do
    attrs = Map.merge(%{"type" => "ein", "country_code" => "US", "value" => ""}, attrs)
    changeset = Parties.change_government_id(attrs)

    assign(socket, :party_government_id_form, to_form(changeset, as: :party_government_id))
  end

  defp party_address_fields do
    [:address_line1, :address_line2, :locality, :region, :postal_code, :country_code]
  end

  defp address_present?(party) do
    party
    |> Map.take(party_address_fields())
    |> Enum.any?(fn {_field, value} -> value not in [nil, ""] end)
  end

  defp government_id_summary(nil), do: "Not added"

  defp government_id_summary(government_id) do
    [
      String.upcase(to_string(government_id.type)),
      government_id.country_code,
      government_id.value
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp render_compliance_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp compliance_review_badge_classes("created"), do: "badge badge-soft badge-warning"
  defp compliance_review_badge_classes("manual_review"), do: "badge badge-soft badge-warning"
  defp compliance_review_badge_classes("approved"), do: "badge badge-soft badge-success"
  defp compliance_review_badge_classes("rejected"), do: "badge badge-soft badge-error"
  defp compliance_review_badge_classes(_status), do: "badge badge-soft"

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

    socket
    |> assign(:member_form, to_form(changeset, as: :party_member))
    |> assign_member_government_id_form()
  end

  defp assign_member_government_id_form(socket, attrs \\ %{}) do
    attrs = Map.merge(%{"type" => "ssn", "country_code" => "US", "value" => ""}, attrs)
    changeset = Parties.change_government_id(attrs)

    assign(socket, :member_government_id_form, to_form(changeset, as: :government_id))
  end

  defp assign_doc_form(socket, attrs \\ %{}),
    do:
      assign(
        socket,
        :document_form,
        to_form(Map.put_new(attrs, "doc_type", "other"), as: :document)
      )

  defp image_upload_entry?(entry) do
    String.starts_with?(entry.client_type || "", "image/")
  end

  defp image_document?(doc) do
    doc.filename
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in [".jpg", ".jpeg", ".png"]))
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
end
