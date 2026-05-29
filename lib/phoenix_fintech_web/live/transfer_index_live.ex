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
            <h1 class="text-2xl font-semibold">
              All transfers for user
            </h1>
            <p class="mt-1 text-sm text-base-content/70">
              Cross-border movement requests and FX details.
            </p>
          </div>
          <.button navigate={~p"/app/transfers/new"} variant="primary" id="new-transfer-link">
            <.icon name="hero-arrows-right-left" class="size-4" /> Create transfer
          </.button>
        </div>

        <div class="card card-border bg-base-100 shadow-sm">
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Parties</th>
                  <th>Originator amount</th>
                  <th>Counterparty amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody id="transfers-table">
                <tr :if={@transfers == []}>
                  <td colspan="4" class="py-8 text-center text-base-content/60">No transfers yet.</td>
                </tr>
                <tr :for={transfer <- @transfers} id={"transfer-#{transfer.id}"}>
                  <td>
                    <.link
                      navigate={~p"/app/transfers/#{transfer.id}"}
                      class="link link-primary font-medium"
                    >
                      {transfer.originator_party.legal_name} → {transfer.counterparty_party.legal_name}
                    </.link>
                  </td>
                  <td>
                    {transfer.amount_in_originator_currency} {transfer.originator_currency_code}
                  </td>
                  <td>
                    {transfer.amount_in_counterparty_currency} {transfer.counterparty_currency_code}
                  </td>
                  <td>
                    <span class="badge badge-soft badge-info capitalize">{transfer.status}</span>
                  </td>
                </tr>
              </tbody>
            </table>
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

  defp list_transfers_for_current_user(%{id: user_id}),
    do: Transfers.list_transfers_for_user(user_id)

  defp list_transfers_for_current_user(_), do: []
end
