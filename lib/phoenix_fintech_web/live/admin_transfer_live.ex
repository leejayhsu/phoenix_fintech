defmodule PhoenixFintechWeb.AdminTransferLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Compliance
  alias PhoenixFintech.Transfers

  @status_filters [
    %{key: "actionable", label: "Needs action", statuses: Transfers.actionable_statuses()},
    %{key: "deposit_pending", label: "Awaiting deposit", statuses: ["deposit_pending"]},
    %{
      key: "disbursement_pending",
      label: "Awaiting disbursement",
      statuses: ["disbursement_pending"]
    },
    %{
      key: "disbursement_initiated",
      label: "Disbursement in flight",
      statuses: ["disbursement_initiated"]
    },
    %{key: "all", label: "All", statuses: nil}
  ]

  @impl true
  def mount(params, _session, socket) do
    pending_count = length(Transfers.list_transfers_needing_action())
    compliance_pending_count = length(Compliance.list_pending_reviews())

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:current_user, socket.assigns.current_scope.user)
      |> assign(:status_filters, @status_filters)
      |> assign(:admin_actionable_transfer_count, pending_count)
      |> assign(:admin_compliance_pending_count, compliance_pending_count)

    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter_key}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/transfers_processing?filter=#{filter_key}")}
  end

  def handle_event("mark_deposit_received", %{"id" => id}, socket) do
    transfer = Transfers.get_transfer!(id)

    case Transfers.mark_deposit_received(transfer, socket.assigns.current_user) do
      {:ok, _transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deposit marked as received. Transfer is ready for disbursement.")
         |> push_patch(to: ~p"/admin/transfers_processing/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply,
         put_flash(socket, :error, "Could not mark deposit received: #{format_reason(reason)}")}
    end
  end

  def handle_event("initiate_disbursement", %{"id" => id}, socket) do
    transfer = Transfers.get_transfer!(id)

    case Transfers.initiate_disbursement(transfer, socket.assigns.current_user) do
      {:ok, _transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Disbursement initiated.")
         |> push_patch(to: ~p"/admin/transfers_processing/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply,
         put_flash(socket, :error, "Could not initiate disbursement: #{format_reason(reason)}")}
    end
  end

  def handle_event("settle_disbursement", %{"id" => id}, socket) do
    transfer = Transfers.get_transfer!(id)

    case Transfers.settle_disbursement(transfer, socket.assigns.current_user) do
      {:ok, _transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Disbursement settled. Transfer completed.")
         |> push_patch(to: ~p"/admin/transfers_processing/#{id}")}

      {:error, _step, reason, _changes} ->
        {:noreply,
         put_flash(socket, :error, "Could not settle disbursement: #{format_reason(reason)}")}
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
      admin_resources={[]}
      admin_compliance_pending_count={@admin_compliance_pending_count}
      admin_actionable_transfer_count={@admin_actionable_transfer_count}
    >
      <section id="admin-transfer-processing" class="mx-auto max-w-6xl">
        <div class="mb-6 flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 class="text-2xl font-semibold">Transfer processing</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Manually confirm incoming deposits and move disbursements through settlement.
            </p>
          </div>
          <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Back to admin
          </.link>
        </div>

        <%= case @live_action do %>
          <% :index -> %>
            <.transfers_index
              status_filters={@status_filters}
              active_filter={@active_filter}
              transfers={@streams.transfers}
              transfers_empty?={@transfers_empty?}
            />
          <% :show -> %>
            <.transfer_detail transfer={@transfer} />
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  attr :status_filters, :list, required: true
  attr :active_filter, :string, required: true
  attr :transfers, :map, required: true
  attr :transfers_empty?, :boolean, required: true

  defp transfers_index(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex flex-wrap items-center gap-2">
        <.link
          :for={filter <- @status_filters}
          id={"transfer-filter-#{filter.key}"}
          phx-click="set_filter"
          phx-value-filter={filter.key}
          class={[
            "btn btn-sm",
            @active_filter == filter.key && "btn-primary",
            @active_filter != filter.key && "btn-ghost"
          ]}
        >
          {filter.label}
        </.link>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body gap-0 p-0">
          <div class="overflow-x-auto">
            <table class="table table-zebra table-sm">
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Status</th>
                  <th>Amount</th>
                  <th>Originator</th>
                  <th>Counterparty</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="admin-transfers-table" phx-update="stream">
                <tr :if={@transfers_empty?} id="admin-transfers-empty">
                  <td colspan="6" class="py-8 text-center text-base-content/60">
                    No transfers in this view.
                  </td>
                </tr>
                <tr :for={{dom_id, transfer} <- @transfers} id={dom_id} class="hover">
                  <td>
                    <.copy_value id={"admin-transfer-#{transfer.id}-ref-copy"} value={transfer.id} />
                  </td>
                  <td>
                    <span class="badge badge-soft badge-sm">{format_status(transfer.status)}</span>
                  </td>
                  <td>
                    {format_currency_amount(
                      transfer.amount_in_originator_currency,
                      transfer.originator_currency_code
                    )}
                  </td>
                  <td>{transfer.originator_party.legal_name}</td>
                  <td>{transfer.counterparty_party.legal_name}</td>
                  <td class="text-right">
                    <.link
                      navigate={~p"/admin/transfers_processing/#{transfer.id}"}
                      class="btn btn-xs btn-primary"
                    >
                      Process
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :transfer, :map, required: true

  defp transfer_detail(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="card card-border bg-base-200">
        <div class="card-body gap-4">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-xl font-semibold">Transfer</h2>
              <p class="mt-1 text-sm text-base-content/70">
                Reference <span class="font-mono">{@transfer.id}</span>
              </p>
            </div>
            <span class={status_badge_classes(@transfer.status)}>
              {format_status(@transfer.status)}
            </span>
          </div>

          <dl class="grid gap-4 sm:grid-cols-2">
            <.detail_row label="Originator" value={@transfer.originator_party.legal_name} />
            <.detail_row label="Counterparty" value={@transfer.counterparty_party.legal_name} />
            <.detail_row
              label="Originator amount"
              value={
                format_currency_amount(
                  @transfer.amount_in_originator_currency,
                  @transfer.originator_currency_code
                )
              }
            />
            <.detail_row
              label="Counterparty amount"
              value={
                format_currency_amount(
                  @transfer.amount_in_counterparty_currency,
                  @transfer.counterparty_currency_code
                )
              }
            />
            <.detail_row
              label="Created"
              value={Calendar.strftime(@transfer.inserted_at, "%B %-d, %Y %-I:%M %p")}
            />
            <.detail_row label="Created by" value={@transfer.created_by_user.email} />
          </dl>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <.funds_panel
          title="Deposit"
          icon="hero-arrow-down-circle"
          funds={@transfer.deposits}
          currency_code={@transfer.originator_currency_code}
        />
        <.funds_panel
          title="Disbursement"
          icon="hero-arrow-up-circle"
          funds={@transfer.disbursements}
          currency_code={@transfer.counterparty_currency_code}
        />
      </div>

      <.actions_panel transfer={@transfer} />

      <.events_panel transfer={@transfer} />

      <.link navigate={~p"/admin/transfers_processing"} class="btn btn-ghost btn-sm">
        <.icon name="hero-arrow-left" class="size-4" /> Back to transfers
      </.link>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :funds, :list, required: true
  attr :currency_code, :string, required: true

  defp funds_panel(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body">
        <h3 class="card-title text-base">
          <.icon name={@icon} class="size-5 text-base-content/70" /> {@title}
        </h3>

        <div :for={funds <- @funds} class="mt-2 space-y-2 text-sm">
          <dl class="grid gap-3 sm:grid-cols-2">
            <.detail_row label="Amount" value={format_currency_amount(funds.amount, @currency_code)} />
            <.detail_row label="Status" value={format_status(funds.status)} />
          </dl>
        </div>

        <p :if={@funds == []} class="mt-2 text-sm text-base-content/60">
          No {@title |> String.downcase()} record for this transfer.
        </p>
      </div>
    </div>
    """
  end

  attr :transfer, :map, required: true

  defp actions_panel(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body gap-4">
        <div>
          <h3 class="card-title text-base">Actions</h3>
          <p class="mt-1 text-sm text-base-content/70">
            Manually advance funds along the workflow. In a production system these steps would be driven by payment network callbacks.
          </p>
        </div>

        <div class="flex flex-wrap gap-2">
          <button
            :if={@transfer.status == "deposit_pending"}
            id="mark-deposit-received-button"
            type="button"
            phx-click="mark_deposit_received"
            phx-value-id={@transfer.id}
            data-confirm="Confirm that the incoming deposit has been received?"
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-check-badge" class="size-4" /> Mark deposit received
          </button>

          <button
            :if={@transfer.status == "disbursement_pending"}
            id="initiate-disbursement-button"
            type="button"
            phx-click="initiate_disbursement"
            phx-value-id={@transfer.id}
            data-confirm="Initiate the disbursement to the counterparty?"
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-paper-airplane" class="size-4" /> Initiate disbursement
          </button>

          <button
            :if={@transfer.status == "disbursement_initiated"}
            id="settle-disbursement-button"
            type="button"
            phx-click="settle_disbursement"
            phx-value-id={@transfer.id}
            data-confirm="Mark the disbursement as settled?"
            class="btn btn-success btn-sm"
          >
            <.icon name="hero-check-circle" class="size-4" /> Mark disbursement settled
          </button>

          <span
            :if={@transfer.status not in Transfers.actionable_statuses()}
            class="text-sm text-base-content/60"
          >
            No manual actions available for this transfer.
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :transfer, :map, required: true

  defp events_panel(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body">
        <h3 class="card-title text-base">Event history</h3>
        <div class="mt-4 space-y-3">
          <div :if={@transfer.events == []} class="text-sm text-base-content/60">
            No events recorded yet.
          </div>
          <article
            :for={event <- @transfer.events}
            id={"admin-transfer-event-#{event.id}"}
            class="rounded-box border border-base-300 bg-base-100 p-3"
          >
            <div class="flex flex-wrap items-start justify-between gap-2">
              <div>
                <p class="text-sm font-medium">{format_status(event.event_type)}</p>
                <p class="text-xs text-base-content/60">
                  {format_status(event.from_status || "none")} → {format_status(event.to_status)}
                </p>
              </div>
              <time class="text-xs text-base-content/60">
                {Calendar.strftime(event.occurred_at, "%b %-d, %Y %-I:%M %p")}
              </time>
            </div>
            <p :if={event.actor_user} class="mt-2 text-xs text-base-content/60">
              Actor: {event.actor_user.email}
            </p>
          </article>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp detail_row(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
        {@label}
      </dt>
      <dd class="mt-1 text-sm font-medium">{@value}</dd>
    </div>
    """
  end

  defp apply_action(socket, :index, params) do
    filter_key = Map.get(params, "filter", "actionable")
    filter = Enum.find(@status_filters, &(&1.key == filter_key)) || List.first(@status_filters)
    transfers = list_transfers_for_filter(filter)

    socket
    |> assign(:page_title, "Transfer processing")
    |> assign(:active_filter, filter.key)
    |> assign(:transfers_empty?, transfers == [])
    |> stream(:transfers, transfers, reset: true)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    transfer = Transfers.get_transfer!(id)

    socket
    |> assign(:page_title, "Transfer processing")
    |> assign(:transfer, transfer)
  end

  defp list_transfers_for_filter(%{statuses: nil}) do
    Transfers.list_transfers()
  end

  defp list_transfers_for_filter(%{statuses: statuses}) do
    Transfers.list_transfers_by_statuses(statuses)
  end

  defp format_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp status_badge_classes("completed"), do: "badge badge-soft badge-success"
  defp status_badge_classes("deposit_pending"), do: "badge badge-soft badge-warning"
  defp status_badge_classes("disbursement_pending"), do: "badge badge-soft badge-warning"
  defp status_badge_classes("disbursement_initiated"), do: "badge badge-soft badge-info"
  defp status_badge_classes(_status), do: "badge badge-soft"
end
