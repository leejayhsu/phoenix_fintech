defmodule PhoenixFintechWeb.TransferShowLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:transfer, Transfers.get_transfer!(id))
      |> assign(:page_title, "Transfer")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="transfer-show" class="mx-auto max-w-4xl space-y-6">
        <.link navigate={~p"/app/transfers"} class="text-sm text-emerald-700 hover:text-emerald-800">
          ← Back to transfers
        </.link>
        <div class="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
          <h1 class="text-2xl font-semibold text-zinc-950 dark:text-white">Transfer details</h1>
          <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt class="text-zinc-500">Originator</dt>
              <dd class="font-medium">{@transfer.originator_party.legal_name}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Counterparty</dt>
              <dd class="font-medium">{@transfer.counterparty_party.legal_name}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Originator amount</dt>
              <dd class="font-medium">
                {@transfer.amount_in_originator_currency} {@transfer.originator_currency_code}
              </dd>
            </div>
            <div>
              <dt class="text-zinc-500">Counterparty amount</dt>
              <dd class="font-medium">
                {@transfer.amount_in_counterparty_currency} {@transfer.counterparty_currency_code}
              </dd>
            </div>
            <div>
              <dt class="text-zinc-500">Status</dt>
              <dd class="font-medium capitalize">{@transfer.status}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Created by</dt>
              <dd class="font-medium">{@transfer.created_by_user.email}</dd>
            </div>
          </dl>

          <div
            :if={@transfer.fx_quote}
            id="fx-quote-details"
            class="mt-6 rounded-lg bg-zinc-50 p-4 dark:bg-zinc-950"
          >
            <h2 class="text-sm font-semibold">FX Quote</h2>
            <p class="mt-2 text-sm">{@transfer.fx_quote.provider} · rate {@transfer.fx_quote.rate}</p>
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
end
