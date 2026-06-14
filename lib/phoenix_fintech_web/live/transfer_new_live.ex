defmodule PhoenixFintechWeb.TransferNewLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.{Ledger, Parties, Transfers}

  @steps [:originator, :counterparties, :quote, :review]

  @impl true
  def mount(_params, _session, socket) do
    currencies = Ledger.list_currencies()

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
      |> assign(:steps, @steps)
      |> assign(:step, :originator)
      |> assign(:selected_originator_id, nil)
      |> assign(:selected_counterparty_ids, [])
      |> assign(:quote_form, quote_form)
      |> assign(:quote, nil)
      |> assign(:quote_error, nil)

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

        <ul class="steps steps-horizontal w-full overflow-x-auto">
          <li :for={step <- @steps} class={step_classes(step, @step)}>
            {step_label(step)}
          </li>
        </ul>

        <div class="overflow-hidden rounded-box border border-base-300 bg-base-100 shadow-sm">
          <div id="transfer-wizard-track" class={wizard_track_classes(@step)}>
            <section class={panel_classes(@step, :originator)} inert={@step != :originator}>
              <div class="card-body gap-6">
                <div>
                  <h2 class="card-title">1. Choose the originator</h2>
                  <p class="text-sm text-base-content/70">
                    Select the party sending funds.
                  </p>
                </div>

                <div class="grid gap-3 md:grid-cols-2">
                  <button
                    :for={party <- @parties}
                    type="button"
                    id={"originator-party-#{party.id}"}
                    phx-click="choose_originator"
                    phx-value-id={party.id}
                    class={party_card_classes(party.id, @selected_originator_id)}
                  >
                    <span class="flex items-start justify-between gap-3">
                      <span>
                        <span class="block font-medium">{party.legal_name}</span>
                        <span class="mt-1 block text-sm text-base-content/60">
                          {party.country_code} · Tax ID {party.tax_id}
                        </span>
                      </span>
                      <span :if={party.id == @selected_originator_id} class="badge badge-primary">
                        Selected
                      </span>
                    </span>
                  </button>
                </div>

                <div :if={@parties == []} role="alert" class="alert alert-warning">
                  <.icon name="hero-exclamation-triangle" class="size-5" />
                  <span>Create a party before starting a transfer.</span>
                </div>
              </div>
            </section>

            <section class={panel_classes(@step, :counterparties)} inert={@step != :counterparties}>
              <div class="card-body gap-6">
                <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <h2 class="card-title">2. Choose counterparties</h2>
                    <p class="text-sm text-base-content/70">
                      The UI is ready for multiple recipients, but this transfer flow currently supports one counterparty.
                    </p>
                  </div>
                  <span class="badge badge-soft badge-info">
                    {length(@selected_counterparty_ids)} selected
                  </span>
                </div>

                <div class="grid gap-3 md:grid-cols-2">
                  <button
                    :for={party <- counterparty_options(@parties, @selected_originator_id)}
                    type="button"
                    id={"counterparty-party-#{party.id}"}
                    phx-click="choose_counterparty"
                    phx-value-id={party.id}
                    class={party_card_classes(party.id, @selected_counterparty_ids)}
                  >
                    <span class="flex items-start justify-between gap-3">
                      <span>
                        <span class="block font-medium">{party.legal_name}</span>
                        <span class="mt-1 block text-sm text-base-content/60">
                          {party.country_code} · Tax ID {party.tax_id}
                        </span>
                      </span>
                      <span :if={party.id in @selected_counterparty_ids} class="badge badge-primary">
                        Selected
                      </span>
                    </span>
                  </button>
                </div>

                <div class="card-actions justify-between">
                  <button
                    type="button"
                    id="back-to-originator-button"
                    phx-click="go_to_step"
                    phx-value-step="originator"
                    class="btn btn-ghost"
                  >
                    Back
                  </button>
                </div>
              </div>
            </section>

            <section class={panel_classes(@step, :quote)} inert={@step != :quote}>
              <div class="card-body gap-6">
                <div>
                  <h2 class="card-title">3. Generate FX quote</h2>
                  <p class="text-sm text-base-content/70">
                    Enter the amount and currencies. The generated quote is binding once you continue.
                  </p>
                </div>

                <div class="grid gap-3 md:grid-cols-2">
                  <.summary_card
                    label="Originator"
                    party={selected_originator(@parties, @selected_originator_id)}
                  />
                  <.summary_card
                    label="Counterparty"
                    party={selected_counterparty(@parties, @selected_counterparty_ids)}
                  />
                </div>

                <div :if={@quote_error} role="alert" class="alert alert-error alert-soft">
                  <.icon name="hero-exclamation-circle" class="size-5" />
                  <span>{@quote_error}</span>
                </div>

                <.form for={@quote_form} id="transfer-quote-form" phx-submit="generate_quote">
                  <div class="grid gap-4 md:grid-cols-3">
                    <.input
                      field={@quote_form[:amount_in_originator_currency]}
                      type="number"
                      min="0"
                      step="0.01"
                      label="Amount to send"
                    />
                    <.input
                      field={@quote_form[:originator_currency_code]}
                      type="select"
                      label="Send currency"
                      options={currency_options(@currencies)}
                    />
                    <.input
                      field={@quote_form[:counterparty_currency_code]}
                      type="select"
                      label="Destination currency"
                      options={currency_options(@currencies)}
                    />
                  </div>

                  <div class="card-actions mt-6 justify-between">
                    <button
                      type="button"
                      id="back-to-counterparties-button"
                      phx-click="go_to_step"
                      phx-value-step="counterparties"
                      class="btn btn-ghost"
                    >
                      Back
                    </button>
                    <.button variant="primary" type="submit" id="generate-transfer-quote-button">
                      Generate binding quote <.icon name="hero-arrow-right" class="size-4" />
                    </.button>
                  </div>
                </.form>
              </div>
            </section>

            <section class={panel_classes(@step, :review)} inert={@step != :review}>
              <div class="card-body gap-6">
                <div>
                  <h2 class="card-title">4. Review</h2>
                  <p class="text-sm text-base-content/70">
                    Confirm the binding FX quote and create the transfer for internal review.
                  </p>
                </div>

                <div :if={@quote} class="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
                  <div class="card card-border bg-base-100">
                    <div class="card-body p-4">
                      <h3 class="font-medium">Transfer summary</h3>
                      <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                        <div>
                          <dt class="text-base-content/60">Originator</dt>
                          <dd class="mt-1 font-medium">
                            {selected_originator(@parties, @selected_originator_id).legal_name}
                          </dd>
                        </div>
                        <div>
                          <dt class="text-base-content/60">Counterparty</dt>
                          <dd class="mt-1 font-medium">
                            {selected_counterparty(@parties, @selected_counterparty_ids).legal_name}
                          </dd>
                        </div>
                        <div>
                          <dt class="text-base-content/60">Send amount</dt>
                          <dd class="mt-1 font-medium">
                            {@quote.amount_in_originator_currency} {@quote.originator_currency_code}
                          </dd>
                        </div>
                        <div>
                          <dt class="text-base-content/60">Destination amount</dt>
                          <dd class="mt-1 font-medium">
                            {@quote.amount_in_counterparty_currency} {@quote.counterparty_currency_code}
                          </dd>
                        </div>
                      </dl>
                    </div>
                  </div>

                  <div class="card bg-primary text-primary-content">
                    <div class="card-body p-4">
                      <h3 class="font-medium">Locked FX rate</h3>
                      <p class="mt-3 text-3xl font-semibold">
                        {@quote.calculation_snapshot["facts"]["fx_rate"]}
                      </p>
                      <p class="text-sm opacity-80">
                        Quote reference {@quote.id}
                      </p>
                    </div>
                  </div>
                </div>

                <div :if={@quote} class="space-y-2">
                  <div
                    :for={line <- @quote.calculation_snapshot["lines"]}
                    class="flex items-center justify-between gap-4 rounded-box bg-base-200 px-4 py-3 text-sm"
                  >
                    <span class="font-medium">{line["label"]}</span>
                    <span class="text-base-content/70">{line["amount"]} {line["currency_code"]}</span>
                  </div>
                </div>

                <div :if={@quote_error} role="alert" class="alert alert-error alert-soft">
                  <.icon name="hero-exclamation-circle" class="size-5" />
                  <span>{@quote_error}</span>
                </div>

                <div class="card-actions justify-between">
                  <button
                    type="button"
                    id="back-to-quote-button"
                    phx-click="go_to_step"
                    phx-value-step="quote"
                    class="btn btn-ghost"
                  >
                    Back
                  </button>
                  <.button
                    variant="primary"
                    type="button"
                    id="finish-transfer-wizard-button"
                    phx-click="finish_wizard"
                  >
                    Create transfer for review
                  </.button>
                </div>
              </div>
            </section>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :party, :map, default: nil

  def summary_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body p-4">
        <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{@label}</p>
        <p class="mt-2 font-medium">{if @party, do: @party.legal_name, else: "Not selected"}</p>
        <p :if={@party} class="text-sm text-base-content/60">
          {@party.country_code} · Tax ID {@party.tax_id}
        </p>
      </div>
    </div>
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

  defp counterparty_options(parties, nil), do: parties

  defp counterparty_options(parties, originator_party_id),
    do: Enum.reject(parties, &(&1.id == originator_party_id))

  defp selected_originator(parties, party_id), do: Enum.find(parties, &(&1.id == party_id))

  defp selected_counterparty(parties, selected_counterparty_ids),
    do: Enum.find(parties, &(&1.id in selected_counterparty_ids))

  defp currency_options(currencies),
    do: for(currency <- currencies, do: {"#{currency.code} · #{currency.name}", currency.code})

  defp default_currency_code([currency | _]), do: currency.code
  defp default_currency_code([]), do: nil

  defp step_number(step), do: Enum.find_index(@steps, &(&1 == step)) + 1

  defp step_label(:originator), do: "Originator"
  defp step_label(:counterparties), do: "Counterparty"
  defp step_label(:quote), do: "FX quote"
  defp step_label(:review), do: "Review"

  defp step_classes(step, current_step) do
    current_index = Enum.find_index(@steps, &(&1 == current_step))
    step_index = Enum.find_index(@steps, &(&1 == step))

    [
      "step",
      step_index <= current_index && "step-primary"
    ]
  end

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

  defp party_card_classes(party_id, selected_party_id) when is_binary(selected_party_id),
    do: party_card_classes(party_id, [selected_party_id])

  defp party_card_classes(party_id, selected_party_ids) do
    [
      "rounded-box border p-4 text-left transition hover:border-primary hover:bg-base-200",
      party_id in selected_party_ids && "border-primary bg-primary/10",
      party_id not in selected_party_ids && "border-base-300 bg-base-100"
    ]
  end
end
