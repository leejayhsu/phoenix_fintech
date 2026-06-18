defmodule PhoenixFintechWeb.PartyIndexLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Parties

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()

    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, "All parties")
      |> assign(:parties, list_parties_for_current_user(current_user))

    {:ok, socket}
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
      <section id="parties-index" class="mx-auto max-w-5xl">
        <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold">All parties for user</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Businesses onboarded by this user for transfer workflows.
            </p>
          </div>
          <.button navigate={~p"/app/parties/new"} variant="primary" id="new-originator-link">
            <.icon name="hero-plus" class="size-4" /> Create party
          </.button>
        </div>

        <div class="card card-border bg-base-100">
          <div class="overflow-x-auto">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th>Legal name</th>
                  <th>Tax ID</th>
                  <th>Country</th>
                </tr>
              </thead>
              <tbody id="parties-table">
                <tr :if={@parties == []}>
                  <td colspan="3" class="py-8 text-center text-sm text-base-content/60">
                    No parties onboarded yet.
                  </td>
                </tr>
                <tr
                  :for={party <- @parties}
                  id={"party-#{party.id}"}
                  phx-click={JS.navigate(~p"/app/parties/#{party.id}")}
                  class="hover cursor-pointer"
                >
                  <td class="font-medium">
                    {party.legal_name}
                  </td>
                  <td>{party.tax_id}</td>
                  <td>
                    <span class="badge badge-ghost">{party.country_code}</span>
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

  defp assign_current_user(socket) do
    assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
  end

  defp list_parties_for_current_user(%{id: user_id}),
    do: Parties.list_parties_onboarded_by_user(user_id)

  defp list_parties_for_current_user(_), do: []
end
