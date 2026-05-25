defmodule PhoenixFintechWeb.TransferShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @status_steps [:draft, :quoted, :submitted]
  @status_copy %{
    draft: "Draft created",
    quoted: "FX quote locked",
    submitted: "Submitted for settlement"
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
      |> assign(:page_title, "Transfer details")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="transfer-show" class="mx-auto max-w-5xl space-y-6">
        <.link navigate={~p"/app/transfers"} class="inline-flex items-center gap-1 text-sm text-emerald-700 transition hover:text-emerald-800">
          <.icon name="hero-arrow-left" class="size-4" /> Back to transfers
        </.link>

        <div class="overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
          <div class="border-b border-zinc-100 bg-zinc-50/50 px-6 py-5 dark:border-zinc-800 dark:bg-zinc-950/50">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h1 class="text-2xl font-semibold text-zinc-950 dark:text-white">Transfer details</h1>
                <p class="mt-1 text-sm text-zinc-500">
                  Transfer reference: <span id="transfer-reference" class="font-mono text-zinc-700 dark:text-zinc-200">{@transfer.id}</span>
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
                <article class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Originator</h2>
                  <p class="mt-2 text-sm font-medium text-zinc-900 dark:text-zinc-100">{@transfer.originator_party.legal_name}</p>
                </article>
                <article class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
                  <h2 class="text-xs font-semibold uppercase tracking-wide text-zinc-500">Counterparty</h2>
                  <p class="mt-2 text-sm font-medium text-zinc-900 dark:text-zinc-100">{@transfer.counterparty_party.legal_name}</p>
                </article>
              </div>

              <div id="transfer-amounts" class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
                <h2 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Transfer amounts</h2>
                <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                  <div>
                    <dt class="text-zinc-500">Originator amount</dt>
                    <dd class="mt-1 font-medium text-zinc-900 dark:text-zinc-100">{@transfer.amount_in_originator_currency} {@transfer.originator_currency_code}</dd>
                  </div>
                  <div>
                    <dt class="text-zinc-500">Counterparty amount</dt>
                    <dd class="mt-1 font-medium text-zinc-900 dark:text-zinc-100">{@transfer.amount_in_counterparty_currency} {@transfer.counterparty_currency_code}</dd>
                  </div>
                </dl>
              </div>

              <div :if={@transfer.fx_quote} id="fx-quote-details" class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
                <h2 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">FX quote</h2>
                <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                  <div>
                    <dt class="text-zinc-500">Provider</dt>
                    <dd class="mt-1 font-medium text-zinc-900 dark:text-zinc-100">{@transfer.fx_quote.provider}</dd>
                  </div>
                  <div>
                    <dt class="text-zinc-500">Rate</dt>
                    <dd class="mt-1 font-medium text-zinc-900 dark:text-zinc-100">{@transfer.fx_quote.rate}</dd>
                  </div>
                </dl>
              </div>
            </div>

            <aside id="transfer-status-timeline" class="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
              <h2 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Status timeline</h2>
              <ol class="mt-4 space-y-3">
                <li :for={step <- @status_steps} id={"status-step-#{step}"} class="flex items-start gap-3">
                  <span class={timeline_dot_classes(step.state)}></span>
                  <div>
                    <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100">{format_status(step.status)}</p>
                    <p class="text-xs text-zinc-500">{@status_copy[step.status]}</p>
                  </div>
                </li>
              </ol>
              <p class="mt-4 text-xs text-zinc-500">Created by {@transfer.created_by_user.email}</p>
            </aside>
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
    current_index = Enum.find_index(@status_steps, &(&1 == status)) || 0

    Enum.with_index(@status_steps)
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

  defp format_status(status), do: status |> to_string() |> String.capitalize()

  defp status_badge_classes(:draft),
    do: "inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-800"

  defp status_badge_classes(:quoted),
    do: "inline-flex items-center rounded-full bg-sky-100 px-3 py-1 text-xs font-semibold text-sky-800"

  defp status_badge_classes(:submitted),
    do: "inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-800"

  defp timeline_dot_classes(:complete), do: "mt-1 size-2.5 rounded-full bg-emerald-500"
  defp timeline_dot_classes(:current), do: "mt-1 size-2.5 rounded-full bg-sky-500 ring-4 ring-sky-100"
  defp timeline_dot_classes(:upcoming), do: "mt-1 size-2.5 rounded-full bg-zinc-300 dark:bg-zinc-600"
end
