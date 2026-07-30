defmodule PhoenixFintechWeb.TransferShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @workflow_milestones [
    "compliance_approved",
    "deposit_received",
    "disbursement_settled"
  ]

  @status_copy %{
    "compliance_approved" => "Compliance approved",
    "deposit_received" => "Incoming funds received",
    "disbursement_settled" => "Disbursement settled"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transfer = Transfers.get_transfer!(id)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:transfer, transfer)
      |> assign(:status_steps, status_steps_for(transfer))
      |> assign(:status_copy, @status_copy)
      |> assign(:page_title, "Transfer details")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      socket={@socket}
    >
      <section id="transfer-show" class="mx-auto max-w-5xl space-y-6">
        <.link
          navigate={~p"/app/transfers"}
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to transfers
        </.link>

        <div class="card card-border bg-base-200">
          <div class="border-b border-base-300 bg-base-200 px-6 py-5">
            <div class="flex flex-wrap items-center gap-3">
              <h1 class="text-2xl font-semibold">Transfer details</h1>
              <.copy_value id="transfer-reference" value={@transfer.id} />
            </div>
          </div>

          <div class="grid gap-6 px-6 py-6 lg:grid-cols-[2fr_1fr]">
            <div class="grid gap-6 lg:row-span-3 lg:grid-rows-subgrid">
              <div id="transfer-parties" class="grid gap-4 sm:grid-cols-2">
                <article class="card card-border bg-base-100">
                  <div class="card-body p-4">
                    <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                      Originator
                    </h2>
                    <p class="mt-2 text-sm font-medium">
                      {@transfer.originator_party.legal_name}
                    </p>
                  </div>
                </article>
                <article class="card card-border bg-base-100">
                  <div class="card-body p-4">
                    <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                      Counterparty
                    </h2>
                    <p class="mt-2 text-sm font-medium">
                      {@transfer.counterparty_party.legal_name}
                    </p>
                  </div>
                </article>
              </div>

              <div
                id="transfer-amounts"
                class="card card-border bg-base-100"
              >
                <div class="card-body p-4">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Transfer amounts
                  </h2>
                  <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                    <div>
                      <dt class="text-base-content/60">Originator amount</dt>
                      <dd class="mt-1 font-medium">
                        {format_currency_amount(
                          @transfer.amount_in_originator_currency,
                          @transfer.originator_currency_code
                        )}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-base-content/60">Counterparty amount</dt>
                      <dd class="mt-1 font-medium">
                        {format_currency_amount(
                          @transfer.amount_in_counterparty_currency,
                          @transfer.counterparty_currency_code
                        )}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>

              <div
                :if={@transfer.transfer_quote}
                id="transfer-quote-details"
                class="card card-border bg-base-100"
              >
                <div class="card-body p-4">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Transfer quote
                  </h2>
                  <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                    <div>
                      <dt class="text-base-content/60">Customer FX rate</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.transfer_quote.customer_fx_rate}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-base-content/60">Spot FX rate</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.transfer_quote.spot_fx_rate}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-base-content/60">Spread</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.transfer_quote.spread_basis_points} bps ({format_basis_points_as_percentage(
                          @transfer.transfer_quote.spread_basis_points
                        )})
                      </dd>
                    </div>
                    <div>
                      <dt class="text-base-content/60">Quote reference</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.transfer_quote.id}
                      </dd>
                    </div>
                  </dl>
                  <div class="mt-4 space-y-2 text-sm">
                    <div
                      :for={line <- @transfer.transfer_quote.calculation_snapshot["lines"]}
                      class="flex items-center justify-between gap-4 rounded-box bg-base-200 px-3 py-2"
                    >
                      <span class="font-medium">{line["label"]}</span>
                      <span class="text-base-content/60">
                        {format_currency_amount(line["amount"], line["currency_code"])}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <aside class="grid gap-6 lg:row-span-3 lg:grid-rows-subgrid">
              <section id="transfer-status" class="card card-border bg-base-100">
                <div class="card-body p-4">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Status
                  </h2>
                  <div class="mt-2">
                    <span id="transfer-status-badge" class={status_badge_classes(@transfer.status)}>
                      {format_status(@transfer.status)}
                    </span>
                  </div>
                </div>
              </section>

              <section id="transfer-direction" class="card card-border bg-base-100">
                <div class="card-body p-4">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Direction
                  </h2>
                  <div class="mt-2">
                    <span class="badge badge-soft">
                      <.icon
                        name={
                          if @transfer.direction == :send,
                            do: "hero-arrow-up",
                            else: "hero-arrow-down"
                        }
                        class="size-4"
                      />
                      {@transfer.direction |> to_string() |> String.capitalize()}
                    </span>
                  </div>
                </div>
              </section>

              <section
                id="transfer-status-timeline"
                class="card card-border bg-base-100"
              >
                <div class="card-body p-4">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Workflow progress
                  </h2>
                  <ol class="timeline timeline-compact timeline-vertical mt-4">
                    <li
                      :for={step <- @status_steps}
                      id={"status-step-#{step.status}"}
                    >
                      <div class="timeline-middle">
                        <span class={timeline_dot_classes(step.state)}></span>
                      </div>
                      <div class="timeline-end pb-4">
                        <p class="text-sm font-medium">
                          {format_status(step.status)}
                        </p>
                        <p class="text-xs text-base-content/60">{@status_copy[step.status]}</p>
                      </div>
                    </li>
                  </ol>
                </div>
              </section>
            </aside>

            <section id="transfer-events" class="lg:col-span-2">
              <div class="card card-border bg-base-100">
                <div class="card-body p-4">
                  <h2 class="card-title text-sm">Event history</h2>
                  <div class="mt-4 space-y-3">
                    <div :if={@transfer.events == []} class="text-sm text-base-content/60">
                      No events recorded yet.
                    </div>
                    <article
                      :for={event <- @transfer.events}
                      id={"transfer-event-#{event.id}"}
                      class="rounded-box border border-base-300 bg-base-100 p-3"
                    >
                      <div class="flex flex-wrap items-start justify-between gap-2">
                        <div>
                          <p class="text-sm font-medium">{format_event_type(event.event_type)}</p>
                          <p class="text-xs text-base-content/60">
                            {format_status(event.from_status || "none")} → {format_status(
                              event.to_status
                            )}
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
            </section>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))

  defp status_steps_for(transfer) do
    reached_statuses =
      transfer.events
      |> Enum.map(& &1.to_status)
      |> MapSet.new()
      |> MapSet.put(transfer.status)

    for status <- @workflow_milestones, MapSet.member?(reached_statuses, status) do
      %{status: status, state: :complete}
    end
  end

  defp format_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_event_type(event_type), do: format_status(event_type)

  defp status_badge_classes("created"),
    do: "badge badge-soft badge-warning"

  defp status_badge_classes("compliance_review"),
    do: "badge badge-soft badge-info"

  defp status_badge_classes("completed"),
    do: "badge badge-soft badge-success"

  defp status_badge_classes("compliance_rejected"),
    do: "badge badge-soft badge-error"

  defp status_badge_classes("cancelled"),
    do: "badge badge-soft"

  defp status_badge_classes(_status),
    do: "badge badge-soft badge-info"

  defp timeline_dot_classes(:complete), do: "status status-success"
end
