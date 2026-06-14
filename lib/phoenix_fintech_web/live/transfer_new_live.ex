defmodule PhoenixFintechWeb.TransferNewLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.{Fx.SpotRatePublisher, Ledger, Parties, Transfers}
  import PhoenixFintechWeb.TransferNewLive.Components

  @steps [:originator, :counterparties, :quote, :review]

  @impl true
  def mount(_params, _session, socket) do
    currencies = Ledger.list_currencies()
    spot_rate_snapshot = SpotRatePublisher.current_snapshot()

    quote_form =
      %{
        "originator_currency_code" => default_currency_code(currencies),
        "counterparty_currency_code" => default_currency_code(currencies)
      }
      |> to_form(as: :quote)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()
      |> assign(:page_title, "New transfer")
      |> assign(:parties, Parties.list_parties())
      |> assign(:currencies, currencies)
      |> assign(:step, :originator)
      |> assign(:selected_originator_id, nil)
      |> assign(:selected_counterparty_ids, [])
      |> assign(:quote_form, quote_form)
      |> assign(:quote, nil)
      |> assign(:quote_error, nil)
      |> assign(:spot_rates, spot_rate_snapshot.rates)
      |> assign(:spot_rates_updated_at, spot_rate_snapshot.updated_at)

    if connected?(socket), do: SpotRatePublisher.subscribe()

    {:ok, socket}
  end

  @impl true
  def handle_event("choose_originator", %{"id" => party_id}, socket) do
    selected_counterparty_ids =
      Enum.reject(socket.assigns.selected_counterparty_ids, &(&1 == party_id))

    {:noreply,
     socket
     |> assign(:selected_originator_id, party_id)
     |> assign(:selected_counterparty_ids, selected_counterparty_ids)
     |> assign(:step, :counterparties)
     |> clear_quote()}
  end

  def handle_event("choose_counterparty", %{"id" => party_id}, socket) do
    if party_id == socket.assigns.selected_originator_id do
      {:noreply, put_flash(socket, :error, "Counterparty must be different from the originator.")}
    else
      {:noreply,
       socket
       |> assign(:selected_counterparty_ids, [party_id])
       |> assign(:step, :quote)
       |> clear_quote()}
    end
  end

  def handle_event("go_to_step", %{"step" => step}, socket) do
    case Enum.find(@steps, &(Atom.to_string(&1) == step)) do
      nil -> {:noreply, socket}
      step -> {:noreply, assign(socket, :step, allowed_step(step, socket.assigns))}
    end
  end

  def handle_event("generate_quote", %{"quote" => quote_params}, socket) do
    attrs =
      quote_params
      |> Map.put("fx_rate", live_spot_rate(socket.assigns, quote_params))
      |> Map.put("originator_party_id", socket.assigns.selected_originator_id)
      |> Map.put("counterparty_party_id", selected_counterparty_id(socket.assigns))

    case validate_quote_params(attrs) do
      :ok ->
        case Transfers.quote_transfer(socket.assigns.current_user.id, attrs) do
          {:ok, quote} ->
            {:noreply,
             socket
             |> assign(:quote, quote)
             |> assign(:quote_form, to_form(quote_params, as: :quote))
             |> assign(:quote_error, nil)
             |> assign(:step, :review)}

          {:error, :quote, reason, _changes} ->
            {:noreply,
             socket
             |> assign(:quote_form, to_form(quote_params, as: :quote))
             |> assign(:quote_error, quote_error_message(reason))}
        end

      {:error, message} ->
        {:noreply,
         socket
         |> assign(:quote_form, to_form(quote_params, as: :quote))
         |> assign(:quote_error, message)}
    end
  end

  def handle_event("quote_changed", %{"quote" => quote_params}, socket) do
    {:noreply,
     socket
     |> assign(:quote_form, to_form(quote_params, as: :quote))
     |> clear_quote()}
  end

  def handle_event("finish_wizard", _params, %{assigns: %{quote: nil}} = socket) do
    {:noreply, assign(socket, :step, :quote)}
  end

  def handle_event("finish_wizard", _params, socket) do
    case Transfers.create_transfer_from_quote(
           socket.assigns.current_user.id,
           socket.assigns.quote.id
         ) do
      {:ok, transfer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transfer created. Operations and compliance can now review it.")
         |> push_navigate(to: ~p"/app/transfers/#{transfer.id}")}

      {:error, _step, changeset, _changes} ->
        {:noreply,
         socket
         |> assign(:step, :review)
         |> assign(:quote_error, "Unable to create transfer: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_info({:spot_rates, rates, updated_at}, socket) do
    {:noreply,
     socket
     |> assign(:spot_rates, rates)
     |> assign(:spot_rates_updated_at, updated_at)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section id="new-transfer" class="mx-auto max-w-6xl space-y-6">
        <.link navigate={~p"/app/transfers"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Back to transfers
        </.link>

        <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p class="text-sm font-medium text-primary">Transfer wizard</p>
            <h1 class="mt-1 text-3xl font-semibold">Create transfer</h1>
            <p class="mt-2 max-w-2xl text-sm text-base-content/70">
              Choose the parties, lock a binding FX quote, then submit the transfer for operations and compliance review.
            </p>
          </div>
          <progress class="progress progress-primary max-w-xs" value={step_number(@step)} max="4">
          </progress>
        </div>

        <div class="overflow-hidden rounded-box border border-base-300 bg-base-100 shadow-sm">
          <div id="transfer-wizard-track" class={wizard_track_classes(@step)}>
            <.originator_step
              panel_class={panel_classes(@step, :originator)}
              active={@step == :originator}
              parties={@parties}
              selected_originator_id={@selected_originator_id}
            />
            <.counterparties_step
              panel_class={panel_classes(@step, :counterparties)}
              active={@step == :counterparties}
              parties={@parties}
              selected_originator_id={@selected_originator_id}
              selected_counterparty_ids={@selected_counterparty_ids}
            />
            <.quote_step
              panel_class={panel_classes(@step, :quote)}
              active={@step == :quote}
              quote_error={@quote_error}
              quote_form={@quote_form}
              parties={@parties}
              selected_originator_id={@selected_originator_id}
              selected_counterparty_ids={@selected_counterparty_ids}
              currencies={@currencies}
              spot_rates={@spot_rates}
              spot_rates_updated_at={@spot_rates_updated_at}
            />
            <.review_step
              panel_class={panel_classes(@step, :review)}
              active={@step == :review}
              quote={@quote}
              quote_error={@quote_error}
              parties={@parties}
              selected_originator_id={@selected_originator_id}
              selected_counterparty_ids={@selected_counterparty_ids}
            />
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

  defp allowed_step(:originator, _assigns), do: :originator

  defp allowed_step(:counterparties, %{selected_originator_id: nil}), do: :originator
  defp allowed_step(:counterparties, _assigns), do: :counterparties

  defp allowed_step(:quote, %{selected_counterparty_ids: []}), do: :counterparties
  defp allowed_step(:quote, _assigns), do: :quote

  defp allowed_step(:review, %{quote: nil}), do: :quote
  defp allowed_step(:review, _assigns), do: :review

  defp clear_quote(socket), do: assign(socket, quote: nil, quote_error: nil)

  defp selected_counterparty_id(%{selected_counterparty_ids: [party_id | _]}), do: party_id
  defp selected_counterparty_id(_assigns), do: nil

  defp validate_quote_params(%{"originator_party_id" => nil}),
    do: {:error, "Choose an originator."}

  defp validate_quote_params(%{"counterparty_party_id" => nil}),
    do: {:error, "Choose a counterparty."}

  defp validate_quote_params(%{"originator_currency_code" => currency_code})
       when currency_code in [nil, ""],
       do: {:error, "Choose a send currency."}

  defp validate_quote_params(%{"counterparty_currency_code" => currency_code})
       when currency_code in [nil, ""],
       do: {:error, "Choose a destination currency."}

  defp validate_quote_params(%{"amount_in_originator_currency" => amount})
       when amount in [nil, ""], do: {:error, "Enter an amount to send."}

  defp validate_quote_params(%{"amount_in_originator_currency" => amount}) do
    case Decimal.parse(amount) do
      {decimal, ""} ->
        if Decimal.compare(decimal, 0) == :gt,
          do: :ok,
          else: {:error, "Amount must be greater than zero."}

      _ ->
        {:error, "Enter a valid amount."}
    end
  end

  defp quote_error_message(:missing_fx_rate),
    do: "Unable to generate an FX rate for that currency pair."

  defp quote_error_message(reason), do: "Unable to generate quote: #{inspect(reason)}"

  defp live_spot_rate(assigns, quote_params) do
    Map.get(assigns.spot_rates, {
      Map.get(quote_params, "originator_currency_code"),
      Map.get(quote_params, "counterparty_currency_code")
    })
  end

  defp default_currency_code([currency | _]), do: currency.code
  defp default_currency_code([]), do: nil

  defp step_number(step), do: Enum.find_index(@steps, &(&1 == step)) + 1

  defp wizard_track_classes(:originator), do: base_track_classes() ++ ["translate-x-0"]
  defp wizard_track_classes(:counterparties), do: base_track_classes() ++ ["-translate-x-1/4"]
  defp wizard_track_classes(:quote), do: base_track_classes() ++ ["-translate-x-1/2"]
  defp wizard_track_classes(:review), do: base_track_classes() ++ ["-translate-x-3/4"]

  defp base_track_classes,
    do: ["flex w-[400%] transition-transform duration-300 ease-out motion-reduce:transition-none"]

  defp panel_classes(current_step, panel_step) do
    [
      "card min-h-[32rem] w-1/4 shrink-0 transition-opacity duration-200",
      current_step == panel_step && "opacity-100",
      current_step != panel_step && "pointer-events-none opacity-40"
    ]
  end
end
