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
      <section id="day-quotes-index" class="mx-auto max-w-7xl space-y-4">
        <h1 class="text-3xl font-semibold">Day Quotes</h1>

        <div class="grid items-start gap-6 lg:grid-cols-[minmax(20rem,0.8fr)_minmax(0,1.6fr)]">
          <div class="card card-border bg-base-100">
            <.form
              for={@form}
              id="create-day-quote-form"
              phx-change="quote_changed"
              phx-submit="create_quote"
            >
              <div class="p-5 sm:p-6">
                <h2 class="text-xl font-semibold">Create a Day Quote</h2>

                <div class="mt-4 space-y-5">
                  <div :if={@form_error} role="alert" class="alert alert-error alert-soft text-sm">
                    <.icon name="hero-exclamation-circle" class="size-5" />
                    <span>{@form_error}</span>
                  </div>

                  <div class="space-y-5">
                    <.quote_terms_fields
                      form={@form}
                      currencies={@currencies}
                      currency_prompt="Choose"
                      currency_codes_only={true}
                      split={true}
                    />

                    <div>
                      <.spot_rate_card
                        :if={any_currency_selected?(@form)}
                        rate={selected_spot_rate(@spot_rates, @form.params)}
                        from_currency_code={@form.params["originator_currency_code"]}
                        to_currency_code={@form.params["counterparty_currency_code"]}
                        updated_at={@spot_rates_updated_at}
                        vertical={true}
                      />
                      <div
                        :if={!any_currency_selected?(@form)}
                        class="card card-border bg-base-200"
                      >
                        <div class="card-body h-24 items-center justify-center text-center">
                          <span class="flex size-10 items-center justify-center rounded-box bg-base-300">
                            <.icon name="hero-chart-bar" class="size-5 text-base-content/60" />
                          </span>
                          <p class="flex-none font-medium">Live FX rate</p>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="flex flex-col gap-4">
                    <div class="flex items-center gap-2 text-sm text-info">
                      <.icon name="hero-clock" class="size-5 shrink-0" />
                      <span>Expires today at 11:59 PM UTC</span>
                    </div>
                    <div class="flex justify-end">
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

          <div class="card card-border min-w-0 bg-base-100">
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
                      <th>Spot Rate</th>
                      <th>Spread (bps)</th>
                      <th>Status</th>
                      <th>Created</th>
                    </tr>
                  </thead>
                  <tbody id="day-quotes-table" phx-update="stream">
                    <tr id="day-quotes-empty" class="hidden only:table-row">
                      <td colspan="5" class="py-10 text-center text-base-content/60">
                        No Day Quotes yet. Create your first one using the form.
                      </td>
                    </tr>
                    <tr :for={{id, quote} <- @streams.quotes} id={id}>
                      <td class="font-semibold">
                        {quote.originator_currency_code}/{quote.counterparty_currency_code}
                      </td>
                      <td class="font-mono text-sm">{format_rate(quote.customer_fx_rate)}</td>
                      <td>{quote.spread_basis_points}</td>
                      <td>
                        <span class={status_badge_classes(quote)}>{quote_status(quote)}</span>
                      </td>
                      <td class="whitespace-nowrap text-sm text-base-content/70">
                        {format_date(quote.inserted_at)}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
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

  defp any_currency_selected?(form) do
    form.params["originator_currency_code"] not in [nil, ""] or
      form.params["counterparty_currency_code"] not in [nil, ""]
  end

  defp selected_spot_rate(rates, params) do
    Map.get(rates, {
      Map.get(params, "originator_currency_code"),
      Map.get(params, "counterparty_currency_code")
    })
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

  defp format_date(datetime), do: Calendar.strftime(datetime, "%b %-d, %Y")

  defp changeset_error(changeset) do
    changeset.errors
    |> List.first()
    |> case do
      {field, {message, _options}} -> "#{Phoenix.Naming.humanize(field)} #{message}."
      nil -> "Unable to create the Day Quote."
    end
  end
end
