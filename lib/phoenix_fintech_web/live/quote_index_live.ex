defmodule PhoenixFintechWeb.QuoteIndexLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.{Fx.SpotRatePublisher, Ledger, Transfers}

  import PhoenixFintechWeb.TransferNewLive.Components,
    only: [quote_terms_fields: 1, spot_rate_card: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_current_user()

    currencies = Ledger.list_currencies()
    quotes = Transfers.list_reusable_quotes_for_user(socket.assigns.current_user.id)
    spot_rate_snapshot = SpotRatePublisher.current_snapshot()

    if connected?(socket), do: SpotRatePublisher.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Day Quotes")
     |> assign(:currencies, currencies)
     |> assign(:form, quote_form(currencies))
     |> assign(:form_error, nil)
     |> assign(:spot_rates, spot_rate_snapshot.rates)
     |> assign(:spot_rates_updated_at, spot_rate_snapshot.updated_at)
     |> stream(:quotes, quotes)}
  end

  @impl true
  def handle_event("open_create_quote", _params, socket) do
    {:noreply,
     socket
     |> assign(:form, quote_form(socket.assigns.currencies))
     |> assign(:form_error, nil)
     |> push_event("open_dialog", %{id: "create-day-quote-dialog"})}
  end

  def handle_event("close_create_quote", _params, socket) do
    {:noreply,
     socket
     |> assign(:form, quote_form(socket.assigns.currencies))
     |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("quote_changed", %{"quote" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :quote))
     |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("create_quote", %{"quote" => params}, socket) do
    params = Map.put(params, "fx_rate", selected_spot_rate(socket.assigns.spot_rates, params))

    case Transfers.create_reusable_quote(socket.assigns.current_user.id, params) do
      {:ok, quote} ->
        {:noreply,
         socket
         |> assign(:form, quote_form(socket.assigns.currencies))
         |> assign(:form_error, nil)
         |> stream_insert(:quotes, quote, at: 0)
         |> push_event("close_dialog", %{id: "create-day-quote-dialog"})
         |> put_flash(:info, "Day Quote created and available until the end of today.")}

      {:error, :invalid_terms} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :quote))
         |> assign(:form_error, "Choose two currencies and enter a spread from 0 to 9,999 bps.")}

      {:error, :missing_fx_rate} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :quote))
         |> assign(:form_error, "A live rate is not available for that currency pair.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :quote))
         |> assign(:form_error, changeset_error(changeset))}
    end
  end

  def handle_event("recreate_quote", %{"id" => quote_id}, socket) do
    quote = Transfers.get_reusable_quote_for_user(socket.assigns.current_user.id, quote_id)
    fx_rate = quote && rate_for_pair(socket.assigns.spot_rates, quote)

    case Transfers.recreate_reusable_quote(socket.assigns.current_user.id, quote_id, fx_rate) do
      {:ok, quote} ->
        {:noreply,
         socket
         |> stream_insert(:quotes, quote, at: 0)
         |> put_flash(:info, "Day Quote recreated using the current market rate.")}

      {:error, :missing_fx_rate} ->
        {:noreply, put_flash(socket, :error, "A live rate is not available for that pair.")}

      _error ->
        {:noreply, put_flash(socket, :error, "That Day Quote could not be recreated.")}
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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      socket={@socket}
    >
      <section id="day-quotes-index" class="mx-auto max-w-7xl space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-sm font-medium text-primary">FX pricing</p>
            <h1 class="mt-1 text-3xl font-semibold">Day Quotes</h1>
            <p class="mt-2 max-w-2xl text-sm text-base-content/70">
              Lock currency terms once, then reuse them across transfers until 11:59 PM UTC today.
            </p>
          </div>
          <button
            id="open-create-day-quote-button"
            type="button"
            phx-click="open_create_quote"
            class="btn btn-primary shrink-0"
          >
            <.icon name="hero-plus" class="size-4" /> Create Day Quote
          </button>
        </div>

        <div class="card card-border bg-base-100">
          <div class="card-body gap-4">
            <div>
              <h2 class="card-title">Quote history</h2>
              <p class="text-sm text-base-content/60">Current and expired reusable quotes.</p>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Pair</th>
                    <th>Customer rate</th>
                    <th>Spread</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th><span class="sr-only">Actions</span></th>
                  </tr>
                </thead>
                <tbody id="day-quotes-table" phx-update="stream">
                  <tr id="day-quotes-empty" class="hidden only:table-row">
                    <td colspan="6" class="py-10 text-center text-base-content/60">
                      No Day Quotes yet. Create your first one using the form.
                    </td>
                  </tr>
                  <tr :for={{id, quote} <- @streams.quotes} id={id}>
                    <td class="font-semibold">
                      {quote.originator_currency_code}/{quote.counterparty_currency_code}
                    </td>
                    <td class="font-mono text-sm">{format_rate(quote.customer_fx_rate)}</td>
                    <td>{quote.spread_basis_points} bps</td>
                    <td>
                      <span class={status_badge_classes(quote)}>{quote_status(quote)}</span>
                    </td>
                    <td class="whitespace-nowrap text-sm text-base-content/70">
                      {format_datetime(quote.inserted_at)}
                    </td>
                    <td class="text-right">
                      <button
                        id={"recreate-day-quote-#{quote.id}"}
                        type="button"
                        phx-click="recreate_quote"
                        phx-value-id={quote.id}
                        class="btn btn-ghost btn-sm"
                      >
                        <.icon name="hero-arrow-path" class="size-4" /> Recreate
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <dialog
          id="create-day-quote-dialog"
          class="modal"
          phx-hook=".DayQuoteDialog"
          data-close-event="close_create_quote"
        >
          <div class="modal-box w-[calc(100%-2rem)] max-w-lg! p-0">
            <.form
              for={@form}
              id="create-day-quote-form"
              phx-change="quote_changed"
              phx-submit="create_quote"
            >
              <div class="p-5 sm:p-6">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <h2 class="text-xl font-semibold">Create a Day Quote</h2>
                    <p class="mt-1 text-sm text-base-content/60">
                      The current spot rate is captured when you create it.
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click={JS.dispatch("phx:close-dialog", to: "#create-day-quote-dialog")}
                    class="btn btn-ghost btn-circle btn-sm"
                    aria-label="Close dialog"
                  >
                    <.icon name="hero-x-mark" class="size-5" />
                  </button>
                </div>

                <div class="mt-5 space-y-5">
                  <div :if={@form_error} role="alert" class="alert alert-error alert-soft text-sm">
                    <.icon name="hero-exclamation-circle" class="size-5" />
                    <span>{@form_error}</span>
                  </div>

                  <div class="grid gap-5 md:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] md:items-center">
                    <div>
                      <.quote_terms_fields
                        form={@form}
                        currencies={@currencies}
                        currency_prompt="Choose"
                        currency_codes_only={true}
                        stacked={true}
                      />
                    </div>

                    <div class="min-w-0">
                      <.spot_rate_card
                        :if={currencies_selected?(@form)}
                        rate={selected_spot_rate(@spot_rates, @form.params)}
                        from_currency_code={@form.params["originator_currency_code"]}
                        to_currency_code={@form.params["counterparty_currency_code"]}
                        updated_at={@spot_rates_updated_at}
                        vertical={true}
                      />
                      <div
                        :if={!currencies_selected?(@form)}
                        class="card card-border h-full bg-base-200"
                      >
                        <div class="card-body min-h-60 items-center justify-center text-center">
                          <span class="flex size-10 items-center justify-center rounded-box bg-base-300">
                            <.icon name="hero-chart-bar" class="size-5 text-base-content/60" />
                          </span>
                          <p class="flex-none font-medium">Live FX rate</p>
                          <p class="flex-none text-sm text-base-content/60">
                            Choose both currencies to see the current rate.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="flex flex-col gap-4">
                    <div class="flex items-center gap-2 text-sm text-info">
                      <.icon name="hero-clock" class="size-5 shrink-0" />
                      <span>Expires today at 11:59 PM UTC</span>
                    </div>
                    <div class="flex justify-end gap-3">
                      <button
                        type="button"
                        phx-click={JS.dispatch("phx:close-dialog", to: "#create-day-quote-dialog")}
                        class="btn btn-ghost"
                      >
                        Cancel
                      </button>
                      <button
                        id="create-day-quote-button"
                        type="submit"
                        disabled={!currencies_selected?(@form)}
                        class="btn btn-primary"
                      >
                        Create Day Quote <.icon name="hero-arrow-right" class="size-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </.form>
          </div>
          <button
            type="button"
            phx-click={JS.dispatch("phx:close-dialog", to: "#create-day-quote-dialog")}
            class="modal-backdrop"
            aria-label="Close dialog"
          >
            close
          </button>
        </dialog>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".DayQuoteDialog">
          export default {
            mounted() {
              this.handleEvent("open_dialog", ({id}) => {
                if (id === this.el.id && !this.el.open) this.el.showModal()
              })
              this.handleEvent("close_dialog", ({id}) => {
                if (id === this.el.id && this.el.open) this.el.close()
              })
              this.el.addEventListener("phx:close-dialog", () => {
                if (this.el.open) this.el.close()
              })
              this.el.addEventListener("close", () => this.pushEvent(this.el.dataset.closeEvent, {}))
            },
            beforeUpdate() {
              this.wasOpen = this.el.open
              this.focusedElementId = document.activeElement?.id
            },
            updated() {
              if (this.wasOpen && !this.el.open) this.el.showModal()
              const focusedElement = document.getElementById(this.focusedElementId)
              if (focusedElement && document.activeElement !== focusedElement) focusedElement.focus()
            }
          }
        </script>
      </section>
    </Layouts.app>
    """
  end

  defp quote_form(_currencies) do
    to_form(
      %{
        "originator_currency_code" => nil,
        "counterparty_currency_code" => nil,
        "spread_basis_points" => "100"
      },
      as: :quote
    )
  end

  defp currencies_selected?(form) do
    form.params["originator_currency_code"] not in [nil, ""] and
      form.params["counterparty_currency_code"] not in [nil, ""]
  end

  defp selected_spot_rate(rates, params) do
    Map.get(rates, {
      Map.get(params, "originator_currency_code"),
      Map.get(params, "counterparty_currency_code")
    })
  end

  defp rate_for_pair(rates, quote) do
    Map.get(rates, {quote.originator_currency_code, quote.counterparty_currency_code})
  end

  defp assign_current_user(socket) do
    assign(socket, :current_user, socket.assigns.current_scope.user)
  end

  defp quote_status(quote) do
    if active?(quote), do: "Active", else: "Expired"
  end

  defp status_badge_classes(quote) do
    ["badge badge-soft", if(active?(quote), do: "badge-success", else: "badge-ghost")]
  end

  defp active?(quote), do: DateTime.after?(quote.expires_at, DateTime.utc_now(:second))

  defp format_rate(rate), do: Decimal.to_string(rate, :normal)

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%b %-d, %Y %H:%M UTC")

  defp changeset_error(changeset) do
    changeset.errors
    |> List.first()
    |> case do
      {field, {message, _options}} -> "#{Phoenix.Naming.humanize(field)} #{message}."
      nil -> "Unable to create the Day Quote."
    end
  end
end
