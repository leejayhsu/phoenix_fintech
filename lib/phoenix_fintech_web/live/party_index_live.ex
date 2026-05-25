defmodule PhoenixFintechWeb.PartyIndexLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:page_title, "Parties")
      |> assign(:parties, Parties.list_parties())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="parties-index" class="mx-auto max-w-5xl">
        <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-zinc-950 dark:text-white">Parties</h1>
            <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-300">
              Businesses onboarded as originators for transfer workflows.
            </p>
          </div>
          <.button navigate={~p"/app/parties/new"} variant="primary" id="new-originator-link">
            <.icon name="hero-plus" class="size-4" /> New originator
          </.button>
        </div>

        <div class="overflow-hidden rounded-lg border border-zinc-200 bg-white shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
          <table class="w-full text-left text-sm">
            <thead class="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500 dark:bg-zinc-950">
              <tr>
                <th class="px-4 py-3">Legal name</th>
                <th class="px-4 py-3">Tax ID</th>
                <th class="px-4 py-3">Country</th>
              </tr>
            </thead>
            <tbody id="parties-table" class="divide-y divide-zinc-100 dark:divide-zinc-800">
              <tr :if={@parties == []}>
                <td colspan="3" class="px-4 py-8 text-center text-sm text-zinc-500">
                  No parties onboarded yet.
                </td>
              </tr>
              <tr :for={party <- @parties} id={"party-#{party.id}"}>
                <td class="px-4 py-3 font-medium text-zinc-950 dark:text-white">
                  {party.legal_name}
                </td>
                <td class="px-4 py-3 text-zinc-600 dark:text-zinc-300">{party.tax_id}</td>
                <td class="px-4 py-3 text-zinc-600 dark:text-zinc-300">{party.country_code}</td>
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

  defp assign_current_user(socket) do
    assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
  end
end
