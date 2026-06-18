defmodule PhoenixFintechWeb.AdminLive do
  use PhoenixFintechWeb, :live_view

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias PhoenixFintech.Accounts.{User, UserToken}
  alias PhoenixFintech.Compliance

  alias PhoenixFintech.Ledger.{Account, AccountBalance, Currency, Entry, JournalEntry}
  alias PhoenixFintech.Parties.{ComplianceDocument, GovernmentID, Party, PartyMember}
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Transfers.{Transfer, TransferQuote}

  @resources [
    %{key: "users", label: "Users", schema: User},
    %{key: "user_tokens", label: "User tokens", schema: UserToken},
    %{key: "parties", label: "Parties", schema: Party},
    %{key: "party_members", label: "Party members", schema: PartyMember},
    %{key: "government_ids", label: "Government IDs", schema: GovernmentID},
    %{key: "compliance_documents", label: "Compliance documents", schema: ComplianceDocument},
    %{key: "transfers", label: "Transfers", schema: Transfer},
    %{key: "transfer_quotes", label: "Transfer quotes", schema: TransferQuote},
    %{key: "ledger_accounts", label: "Ledger accounts", schema: Account},
    %{key: "ledger_account_balances", label: "Ledger account balances", schema: AccountBalance},
    %{key: "ledger_entries", label: "Ledger entries", schema: Entry},
    %{key: "ledger_journal_entries", label: "Ledger journal entries", schema: JournalEntry},
    %{key: "currencies", label: "Currencies", schema: Currency}
  ]

  @impl true
  def mount(params, _session, socket) do
    pending_count = length(Compliance.list_pending_reviews())

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:current_user, socket.assigns.current_scope.user)
      |> assign(:resources, @resources)
      |> assign(:admin_compliance_pending_count, pending_count)

    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", %{"record" => params}, socket) do
    changeset =
      socket.assigns.record
      |> changeset_for(socket.assigns.resource, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :record))}
  end

  def handle_event("save", %{"record" => params}, socket) do
    changeset = changeset_for(socket.assigns.record, socket.assigns.resource, params)

    case Repo.update(changeset) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Record updated.")
         |> push_navigate(to: ~p"/admin/#{socket.assigns.resource.key}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :record))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Repo.get!(socket.assigns.resource.schema, id)

    case delete_record(socket.assigns.resource, record) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> stream_delete(:records, record)
         |> put_flash(:info, "Record deleted.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not delete record.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      section={:admin}
      admin_resources={@resources}
      admin_resource={@resource}
    >
      <section id="admin-panel" class="mx-auto max-w-7xl">
        <div class="mb-6">
          <div>
            <h1 class="text-2xl font-semibold">Admin</h1>
            <p class="mt-1 text-sm text-base-content/70">
              View and edit application records.
            </p>
          </div>
        </div>

        <div>
          <%= case @live_action do %>
            <% :index -> %>
              <div class="card card-border bg-base-100">
                <div class="card-body">
                  <h2 class="card-title">Choose a resource</h2>
                  <p class="text-sm text-base-content/70">
                    Select a model from the sidebar to view and edit records.
                  </p>
                </div>
              </div>
            <% :resource -> %>
              <div class="card card-border bg-base-100">
                <div class="card-body gap-4 p-0">
                  <div class="border-b border-base-300 p-4">
                    <h2 class="card-title">{@resource.label}</h2>
                    <p class="text-sm text-base-content/70">
                      Showing the most recent 100 records from {@resource.schema.__schema__(:source)}.
                    </p>
                  </div>

                  <div class="overflow-x-clip">
                    <%= cond do %>
                      <% @resource.key == "transfers" -> %>
                        <table class="table table-zebra table-sm">
                          <thead>
                            <tr>
                              <th>ID</th>
                              <th>Status</th>
                              <th>Amount</th>
                              <th>Originator ID</th>
                              <th class="text-right">Actions</th>
                            </tr>
                          </thead>
                          <tbody id="admin-records" phx-update="stream">
                            <tr :if={@records_empty?} id="admin-records-empty">
                              <td colspan="5" class="py-8 text-center text-base-content/60">
                                No records found.
                              </td>
                            </tr>
                            <tr :for={{dom_id, record} <- @streams.records} id={dom_id}>
                              <td>
                                <.copy_value
                                  id={"transfer-#{record.id}-id-copy"}
                                  value={record.id}
                                />
                              </td>
                              <td>
                                <span class="badge badge-sm badge-ghost">{record.status}</span>
                              </td>
                              <td>
                                {format_currency_amount(
                                  record.amount_in_originator_currency,
                                  record.originator_currency_code
                                )}
                              </td>
                              <td>
                                <.copy_value
                                  id={"transfer-#{record.id}-originator-copy"}
                                  value={record.originator_party_id}
                                />
                              </td>
                              <td class="text-right">
                                <.actions_dropdown resource_key={@resource.key} record={record} />
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      <% @resource.key == "parties" -> %>
                        <table class="table table-zebra table-sm">
                          <thead>
                            <tr>
                              <th>ID</th>
                              <th>Legal name</th>
                              <th>Region</th>
                              <th class="text-right">Actions</th>
                            </tr>
                          </thead>
                          <tbody id="admin-records" phx-update="stream">
                            <tr :if={@records_empty?} id="admin-records-empty">
                              <td colspan="4" class="py-8 text-center text-base-content/60">
                                No records found.
                              </td>
                            </tr>
                            <tr :for={{dom_id, record} <- @streams.records} id={dom_id}>
                              <td>
                                <.copy_value id={"party-#{record.id}-id-copy"} value={record.id} />
                              </td>
                              <td>{record.legal_name}</td>
                              <td>{record.region}</td>
                              <td class="text-right">
                                <.actions_dropdown resource_key={@resource.key} record={record} />
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      <% true -> %>
                        <table class="table table-zebra table-sm">
                          <thead>
                            <tr>
                              <th :for={field <- @list_fields}>{field}</th>
                              <th class="text-right">Actions</th>
                            </tr>
                          </thead>
                          <tbody id="admin-records" phx-update="stream">
                            <tr :if={@records_empty?} id="admin-records-empty">
                              <td
                                colspan={length(@list_fields) + 1}
                                class="py-8 text-center text-base-content/60"
                              >
                                No records found.
                              </td>
                            </tr>
                            <tr :for={{dom_id, record} <- @streams.records} id={dom_id}>
                              <td :for={field <- @list_fields} class="max-w-64 truncate">
                                {format_value(Map.get(record, field))}
                              </td>
                              <td class="text-right">
                                <.actions_dropdown resource_key={@resource.key} record={record} />
                              </td>
                            </tr>
                          </tbody>
                        </table>
                    <% end %>
                  </div>
                </div>
              </div>
            <% :edit -> %>
              <div class="card card-border bg-base-100">
                <div class="card-body">
                  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <h2 class="card-title">Edit {@resource.label}</h2>
                      <p class="text-sm text-base-content/70">ID: {record_id(@record)}</p>
                    </div>
                    <.link navigate={~p"/admin/#{@resource.key}"} class="btn btn-ghost btn-sm">
                      Back to list
                    </.link>
                  </div>

                  <.form
                    for={@form}
                    id="admin-record-form"
                    phx-change="validate"
                    phx-submit="save"
                    class="mt-4 grid gap-4"
                  >
                    <div :for={field <- @editable_fields} class="form-control">
                      <.input
                        :if={input_type(@resource.schema, field) not in ["select", "textarea"]}
                        field={@form[field]}
                        type={input_type(@resource.schema, field)}
                        label={Phoenix.Naming.humanize(field)}
                      />

                      <.input
                        :if={input_type(@resource.schema, field) == "select"}
                        field={@form[field]}
                        type="select"
                        label={Phoenix.Naming.humanize(field)}
                        options={enum_options(@resource.schema, field)}
                      />

                      <.input
                        :if={input_type(@resource.schema, field) == "textarea"}
                        field={@form[field]}
                        type="textarea"
                        label={Phoenix.Naming.humanize(field)}
                        value={form_value(@resource.schema, field, @form[field].value)}
                      />
                    </div>

                    <div class="card-actions justify-end">
                      <.link navigate={~p"/admin/#{@resource.key}"} class="btn btn-ghost">
                        Cancel
                      </.link>
                      <.button type="submit" variant="primary">Save changes</.button>
                    </div>
                  </.form>
                </div>
              </div>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Admin")
    |> assign(:resource, nil)
  end

  defp apply_action(socket, :resource, %{"resource" => resource_key}) do
    resource = get_resource!(resource_key)
    records = list_records(resource)

    socket
    |> assign(:page_title, "Admin - #{resource.label}")
    |> assign(:resource, resource)
    |> assign(:list_fields, list_fields(resource.schema))
    |> assign(:records_empty?, records == [])
    |> stream(:records, records, reset: true)
  end

  defp apply_action(socket, :edit, %{"resource" => resource_key, "id" => id}) do
    resource = get_resource!(resource_key)
    record = Repo.get!(resource.schema, id)
    changeset = changeset_for(record, resource, %{})

    socket
    |> assign(:page_title, "Admin - Edit #{resource.label}")
    |> assign(:resource, resource)
    |> assign(:record, record)
    |> assign(:editable_fields, editable_fields(resource.schema))
    |> assign(:form, to_form(changeset, as: :record))
  end

  defp get_resource!(key) do
    Enum.find(@resources, &(&1.key == key)) ||
      raise Phoenix.Router.NoRouteError, conn: nil, router: PhoenixFintechWeb.Router
  end

  defp delete_record(%{key: "parties"}, %Party{} = party) do
    Multi.new()
    |> Multi.delete_all(
      :transfers,
      from(t in Transfer,
        where: t.originator_party_id == ^party.id or t.counterparty_party_id == ^party.id
      )
    )
    |> Multi.delete(:party, party)
    |> Repo.transaction()
    |> case do
      {:ok, %{party: deleted}} -> {:ok, deleted}
      {:error, _op, error, _changes} -> {:error, error}
    end
  end

  defp delete_record(%{key: "transfers"}, %Transfer{} = transfer) do
    Multi.new()
    |> Multi.delete_all(
      :quotes,
      from(q in TransferQuote, where: q.id == ^transfer.transfer_quote_id)
    )
    |> Multi.delete(:transfer, transfer)
    |> Repo.transaction()
    |> case do
      {:ok, %{transfer: deleted}} -> {:ok, deleted}
      {:error, _op, error, _changes} -> {:error, error}
    end
  end

  defp delete_record(_resource, record), do: Repo.delete(record)

  defp list_records(%{schema: schema}) do
    primary_key = primary_key(schema)

    Repo.all(from record in schema, order_by: [desc: field(record, ^primary_key)], limit: 100)
  end

  defp changeset_for(record, resource, params) do
    params = normalize_params(resource.schema, params)

    record
    |> Changeset.change()
    |> Changeset.cast(params, editable_fields(resource.schema))
  end

  defp normalize_params(schema, params) do
    resource_fields = Enum.map(editable_fields(schema), &Atom.to_string/1)

    params
    |> Map.take(resource_fields)
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      field = String.to_existing_atom(key)

      value =
        case schema.__schema__(:type, field) do
          :map -> decode_map(value)
          _ -> value
        end

      Map.put(acc, key, value)
    end)
  end

  defp decode_map(""), do: nil

  defp decode_map(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      {:error, _error} -> value
    end
  end

  defp decode_map(value), do: value

  defp list_fields(schema) do
    schema.__schema__(:fields)
    |> Enum.reject(&(&1 in [:hashed_password, :token]))
    |> Enum.take(8)
  end

  defp editable_fields(schema) do
    schema.__schema__(:fields) --
      [primary_key(schema), :inserted_at, :updated_at, :hashed_password, :token]
  end

  defp primary_key(schema), do: schema.__schema__(:primary_key) |> List.first()

  defp record_id(record), do: Map.fetch!(record, primary_key(record.__struct__))

  defp input_type(schema, field) do
    case schema.__schema__(:type, field) do
      :boolean -> "checkbox"
      :decimal -> "number"
      :integer -> "number"
      :map -> "textarea"
      :utc_datetime -> "datetime-local"
      {:parameterized, Ecto.Enum, _meta} -> "select"
      _ -> "text"
    end
  end

  defp enum_options(schema, field) do
    schema
    |> Ecto.Enum.values(field)
    |> Enum.map(&{Phoenix.Naming.humanize(&1), &1})
  end

  defp form_value(schema, field, value) do
    case {schema.__schema__(:type, field), value} do
      {:map, nil} -> ""
      {:map, value} when is_binary(value) -> value
      {:map, value} -> Jason.encode!(value)
      {_type, value} -> value
    end
  end

  defp format_value(nil), do: "-"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(%Decimal{} = value), do: Decimal.to_string(value)
  defp format_value(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value), do: to_string(value)

  attr :resource_key, :string, required: true
  attr :record, :any, required: true

  defp actions_dropdown(assigns) do
    ~H"""
    <details class="dropdown dropdown-end">
      <summary class="btn btn-xs btn-ghost">
        <.icon name="hero-bars-3" class="size-4" />
      </summary>
      <ul class="menu dropdown-content z-50 mt-1 w-40 rounded-box border border-base-300 bg-base-100 p-2 shadow">
        <li>
          <.link navigate={~p"/admin/#{@resource_key}/#{record_id(@record)}/edit"}>
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </.link>
        </li>
        <li>
          <button
            type="button"
            phx-click="delete"
            phx-value-id={record_id(@record)}
            data-confirm="Are you sure you want to delete this record?"
            class="text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Delete
          </button>
        </li>
      </ul>
    </details>
    """
  end
end
