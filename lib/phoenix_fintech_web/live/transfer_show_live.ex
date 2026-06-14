defmodule PhoenixFintechWeb.TransferShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @status_steps [
    "created",
    "originator_set",
    "counterparty_set",
    "fx_quote_confirmed",
    "compliance_review",
    "compliance_approved",
    "deposit_pending",
    "deposit_received",
    "disbursement_pending",
    "disbursement_initiated",
    "disbursement_settled",
    "completed"
  ]

  @status_copy %{
    "created" => "Transfer record created",
    "originator_set" => "Originator selected",
    "counterparty_set" => "Counterparty selected",
    "fx_quote_confirmed" => "FX quote locked",
    "compliance_review" => "Awaiting compliance review",
    "compliance_approved" => "Compliance approved",
    "compliance_rejected" => "Compliance rejected",
    "deposit_pending" => "Awaiting incoming funds",
    "deposit_received" => "Incoming funds received",
    "disbursement_pending" => "Ready for disbursement",
    "disbursement_initiated" => "Disbursement initiated",
    "disbursement_settled" => "Disbursement settled",
    "completed" => "Transfer completed",
    "cancelled" => "Transfer cancelled"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transfer = Transfers.get_transfer!(id)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:transfer, transfer)
      |> assign(:status_steps, status_steps_for(transfer.status))
      |> assign(:status_copy, @status_copy)
      |> assign(:page_title, "Transfer details")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="transfer-show" class="mx-auto max-w-5xl space-y-6">
        <.link
          navigate={~p"/app/transfers"}
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to transfers
        </.link>

        <div class="card card-border bg-base-200">
          <div class="border-b border-base-300 bg-base-200 px-6 py-5">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h1 class="text-2xl font-semibold">Transfer details</h1>
                <p class="mt-1 text-sm text-base-content/60">
                  Transfer reference:
                  <span id="transfer-reference" class="font-mono text-base-content">
                    {@transfer.id}
                  </span>
                </p>
              </div>
              <span id="transfer-status-badge" class={status_badge_classes(@transfer.status)}>
                {format_status(@transfer.status)}
              </span>
            </div>
          </div>

          <div class="grid gap-6 px-6 py-6 lg:grid-cols-[2fr_1fr]">
            <div class="space-y-6">
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
                  <h2 class="card-title text-sm">Transfer amounts</h2>
                  <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                    <div>
                      <dt class="text-base-content/60">Originator amount</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.amount_in_originator_currency} {@transfer.originator_currency_code}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-base-content/60">Counterparty amount</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.amount_in_counterparty_currency} {@transfer.counterparty_currency_code}
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
                  <h2 class="card-title text-sm">Transfer quote</h2>
                  <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                    <div>
                      <dt class="text-base-content/60">FX rate</dt>
                      <dd class="mt-1 font-medium">
                        {@transfer.transfer_quote.calculation_snapshot["facts"]["fx_rate"]}
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
                        {line["amount"]} {line["currency_code"]}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <aside
              id="transfer-status-timeline"
              class="card card-border bg-base-100"
            >
              <div class="card-body p-4">
                <h2 class="card-title text-sm">Workflow progress</h2>
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
                <p class="mt-4 text-xs text-base-content/60">
                  Created by {@transfer.created_by_user.email}
                </p>
              </div>
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

  defp status_steps_for(status) do
    status_steps = status_steps_for_current_status(status)
    current_index = Enum.find_index(status_steps, &(&1 == status)) || 0

    Enum.with_index(status_steps)
    |> Enum.map(fn {step, index} ->
      state =
        cond do
          index < current_index -> :complete
          index == current_index -> :current
          true -> :upcoming
        end

      %{status: step, state: state}
    end)
  end

  defp status_steps_for_current_status("cancelled"), do: @status_steps ++ ["cancelled"]

  defp status_steps_for_current_status("compliance_rejected") do
    Enum.take_while(@status_steps, &(&1 != "compliance_approved")) ++ ["compliance_rejected"]
  end

  defp status_steps_for_current_status(_status), do: @status_steps

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

  defp timeline_dot_classes(:current),
    do: "status status-info status-lg"

  defp timeline_dot_classes(:upcoming),
    do: "status"
end
