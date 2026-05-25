defmodule PhoenixFintechWeb.TransferNewLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.{Ledger, Parties, Transfers}

  @impl true
  def mount(_params, _session, socket) do
    form = Transfers.change_transfer() |> to_form(as: :transfer)
    quote_form = to_form(%{}, as: :quote)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:page_title, "New transfer")
      |> assign(:parties, Parties.list_parties())
      |> assign(:currencies, Ledger.list_currencies())
      |> assign(:step, :details)
      |> assign(:transfer_form, form)
      |> assign(:quote_form, quote_form)

    {:ok, socket}
  end

  @impl true
  def handle_event("save_details", %{"transfer" => params}, socket) do
    cs = Transfers.change_transfer(params)

    if cs.valid? do
      {:noreply,
       socket
       |> assign(:step, :quote)
       |> assign(:transfer_form, to_form(cs, as: :transfer))}
    else
      {:noreply,
       assign(socket, :transfer_form, to_form(%{cs | action: :validate}, as: :transfer))}
    end
  end

  def handle_event("save_transfer", %{"transfer" => transfer, "quote" => quote}, socket) do
    attrs = Map.put(transfer, "fx_rate", Map.get(quote, "fx_rate"))

    case Transfers.create_transfer(socket.assigns.current_user.id, attrs) do
      {:ok, created} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer created.")
         |> push_navigate(to: ~p"/app/transfers/#{created.id}")}

      {:error, :quote, reason, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to create quote: #{inspect(reason)}")
         |> assign(:quote_form, to_form(quote, as: :quote))}

      {:error, :transfer, cs, _} ->
        {:noreply,
         socket
         |> assign(:step, :details)
         |> assign(:transfer_form, to_form(%{cs | action: :validate}, as: :transfer))}
    end
  end

  def handle_event("back_to_details", _params, socket),
    do: {:noreply, assign(socket, :step, :details)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="new-transfer" class="mx-auto max-w-5xl">
        <h1 class="mb-6 text-3xl font-semibold text-zinc-950 dark:text-white">Create transfer</h1>

        <%= if @step == :details do %>
          <.form for={@transfer_form} id="transfer-details-form" phx-submit="save_details">
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@transfer_form[:originator_party_id]}
                type="select"
                label="Originator party"
                options={for p <- @parties, do: {p.legal_name, p.id}}
              />
              <.input
                field={@transfer_form[:counterparty_party_id]}
                type="select"
                label="Counterparty party"
                options={for p <- @parties, do: {p.legal_name, p.id}}
              />
              <.input
                field={@transfer_form[:originator_currency_code]}
                type="select"
                label="Originator currency"
                options={for c <- @currencies, do: {"#{c.code} · #{c.name}", c.code}}
              />
              <.input
                field={@transfer_form[:counterparty_currency_code]}
                type="select"
                label="Counterparty currency"
                options={for c <- @currencies, do: {"#{c.code} · #{c.name}", c.code}}
              />
              <.input
                field={@transfer_form[:amount_in_originator_currency]}
                type="number"
                step="0.0001"
                label="Amount in originator currency"
              />
              <.input
                field={@transfer_form[:amount_in_counterparty_currency]}
                type="number"
                step="0.0001"
                label="Amount in counterparty currency"
              />
            </div>
            <div class="mt-6 flex justify-end">
              <.button variant="primary" type="submit" id="continue-to-quote-button">
                Continue <.icon name="hero-arrow-right" class="size-4" />
              </.button>
            </div>
          </.form>
        <% else %>
          <.form for={@quote_form} id="transfer-quote-form" phx-submit="save_transfer">
            <input
              type="hidden"
              name="transfer[originator_party_id]"
              value={@transfer_form.params["originator_party_id"]}
            />
            <input
              type="hidden"
              name="transfer[counterparty_party_id]"
              value={@transfer_form.params["counterparty_party_id"]}
            />
            <input
              type="hidden"
              name="transfer[originator_currency_code]"
              value={@transfer_form.params["originator_currency_code"]}
            />
            <input
              type="hidden"
              name="transfer[counterparty_currency_code]"
              value={@transfer_form.params["counterparty_currency_code"]}
            />
            <input
              type="hidden"
              name="transfer[amount_in_originator_currency]"
              value={@transfer_form.params["amount_in_originator_currency"]}
            />
            <input
              type="hidden"
              name="transfer[amount_in_counterparty_currency]"
              value={@transfer_form.params["amount_in_counterparty_currency"]}
            />

            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@quote_form[:fx_rate]} type="number" step="0.0000001" label="FX rate" />
            </div>

            <div class="mt-6 flex justify-between">
              <.button type="button" id="back-to-details-button" phx-click="back_to_details">
                Back
              </.button>
              <.button type="submit" variant="primary" id="create-transfer-button">
                Create transfer
              </.button>
            </div>
          </.form>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  defp current_user(%{user: user}), do: user
  defp current_user(_scope), do: nil

  defp assign_current_user(socket),
    do: assign(socket, :current_user, current_user(socket.assigns[:current_scope]))
end
