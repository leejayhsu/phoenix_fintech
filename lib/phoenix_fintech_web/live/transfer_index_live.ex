defmodule PhoenixFintechWeb.TransferIndexLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Transfers

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()

    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "All transfers")
      |> assign(:transfers, list_transfers_for_current_user(current_user))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="transfers-index" class="mx-auto max-w-6xl">
        <div class="mb-6 flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-semibold text-zinc-950 dark:text-white">
              All transfers for user
            </h1>
            <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-300">
              Cross-border movement requests and FX details.
            </p>
          </div>
          <.button navigate={~p"/app/transfers/new"} variant="primary" id="new-transfer-link">
            <.icon name="hero-arrows-right-left" class="size-4" /> Create transfer
          </.button>
        </div>

        <div class="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
          <table class="w-full text-left text-sm">
            <thead class="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500 dark:bg-zinc-950">
              <tr>
                <th class="px-4 py-3">Parties</th>
                <th class="px-4 py-3">Originator amount</th>
                <th class="px-4 py-3">Counterparty amount</th>
                <th class="px-4 py-3">Status</th>
              </tr>
            </thead>
            <tbody id="transfers-table" class="divide-y divide-zinc-100 dark:divide-zinc-800">
              <tr :if={@transfers == []}>
                <td colspan="4" class="px-4 py-8 text-center text-zinc-500">No transfers yet.</td>
              </tr>
              <tr :for={transfer <- @transfers} id={"transfer-#{transfer.id}"}>
                <td class="px-4 py-3">
                  <.link
                    navigate={~p"/app/transfers/#{transfer.id}"}
                    class="font-medium text-zinc-950 hover:text-emerald-700 dark:text-white"
                  >
                    {transfer.originator_party.legal_name} → {transfer.counterparty_party.legal_name}
                  </.link>
                </td>
                <td class="px-4 py-3">
                  {transfer.amount_in_originator_currency} {transfer.originator_currency_code}
                </td>
                <td class="px-4 py-3">
                  {transfer.amount_in_counterparty_currency} {transfer.counterparty_currency_code}
                </td>
                <td class="px-4 py-3 capitalize">{transfer.status}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))

  defp list_transfers_for_current_user(%{id: user_id}),
    do: Transfers.list_transfers_for_user(user_id)

  defp list_transfers_for_current_user(_), do: []
end
