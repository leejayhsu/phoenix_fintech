defmodule PhoenixFintechWeb.TransferNewLive.Components do
  use PhoenixFintechWeb, :html

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true

  def originator_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body gap-6">
        <div>
          <h2 class="card-title">1. Choose the originator</h2>
          <p class="text-sm text-base-content/70">
            Select the party sending funds.
          </p>
        </div>

        <div class="grid gap-3 md:grid-cols-2">
          <.party_card
            :for={party <- @parties}
            party={party}
            selected={party.id == @selected_originator_id}
            event="choose_originator"
            id_prefix="originator-party"
          />
        </div>

        <div :if={@parties == []} role="alert" class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>Create a party before starting a transfer.</span>
        </div>
      </div>
    </section>
    """
  end

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true
  attr :selected_counterparty_ids, :list, required: true

  def counterparties_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
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
          <.party_card
            :for={party <- counterparty_options(@parties, @selected_originator_id)}
            party={party}
            selected={party.id in @selected_counterparty_ids}
            event="choose_counterparty"
            id_prefix="counterparty-party"
          />
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
    """
  end

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :quote_error, :string, default: nil
  attr :quote_form, Phoenix.HTML.Form, required: true
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true
  attr :selected_counterparty_ids, :list, required: true
  attr :currencies, :list, required: true
  attr :spot_rates, :map, required: true
  attr :spot_rates_updated_at, :any, default: nil

  def quote_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body gap-6">
        <div>
          <h2 class="card-title">3. Generate FX quote</h2>
          <p class="text-sm text-base-content/70">
            Enter the amount and currencies. The generated quote is binding once you continue.
          </p>
        </div>

        <div :if={@quote_error} role="alert" class="alert alert-error alert-soft">
          <.icon name="hero-exclamation-circle" class="size-5" />
          <span>{@quote_error}</span>
        </div>

        <.form
          for={@quote_form}
          id="transfer-quote-form"
          phx-change="quote_changed"
          phx-submit="generate_quote"
        >
          <div class="grid gap-6 lg:grid-cols-2">
            <div class="space-y-4">
              <div class="grid gap-4 sm:grid-cols-2">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Originator
                  </p>
                  <p class="mt-1 font-medium">
                    {selected_party_name(@parties, @selected_originator_id)}
                  </p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Counterparty
                  </p>
                  <p class="mt-1 font-medium">
                    {selected_party_name(@parties, @selected_counterparty_ids)}
                  </p>
                </div>
              </div>

              <.input
                field={@quote_form[:amount_in_originator_currency]}
                type="number"
                min="0"
                step="0.01"
                label="Amount to send"
              />

              <div class="grid gap-4 sm:grid-cols-2">
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
            </div>

            <div class="space-y-4">
              <.spot_rate_card
                rate={selected_spot_rate(@spot_rates, @quote_form)}
                from_currency_code={quote_form_value(@quote_form, :originator_currency_code)}
                to_currency_code={quote_form_value(@quote_form, :counterparty_currency_code)}
                updated_at={@spot_rates_updated_at}
              />

              <% details = fx_details(assigns) %>
              <.fx_details_card :if={details} details={details} />
            </div>
          </div>

          <input
            type="hidden"
            name="quote[fx_rate]"
            value={spot_rate_input_value(selected_spot_rate(@spot_rates, @quote_form))}
          />

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
    """
  end

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :quote, :any, default: nil
  attr :quote_error, :string, default: nil
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true
  attr :selected_counterparty_ids, :list, required: true

  def review_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
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
    """
  end

  attr :party, :map, required: true
  attr :selected, :boolean, required: true
  attr :event, :string, required: true
  attr :id_prefix, :string, required: true

  def party_card(assigns) do
    ~H"""
    <button
      type="button"
      id={"#{@id_prefix}-#{@party.id}"}
      phx-click={@event}
      phx-value-id={@party.id}
      class={party_card_classes(@selected)}
    >
      <span class="flex items-start justify-between gap-3">
        <span>
          <span class="block font-medium">{@party.legal_name}</span>
          <span class="mt-1 block text-sm text-base-content/60">
            {@party.country_code} · Tax ID {@party.tax_id}
          </span>
        </span>
        <span :if={@selected} class="badge badge-primary">
          Selected
        </span>
      </span>
    </button>
    """
  end

  attr :rate, :any, required: true
  attr :from_currency_code, :string, required: true
  attr :to_currency_code, :string, required: true
  attr :updated_at, :any, default: nil

  def spot_rate_card(assigns) do
    ~H"""
    <div class="card card-border mt-4 bg-base-100">
      <div class="card-body gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div class="flex items-center gap-2">
            <span class="badge badge-success badge-soft">Live spot</span>
            <span class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              {@from_currency_code}/{@to_currency_code}
            </span>
            <span
              class="tooltip tooltip-right text-base-content/60"
              data-tip="This rate refreshes every 5 seconds and will be locked when you generate the binding quote."
            >
              <.icon name="hero-information-circle" class="size-4" />
            </span>
          </div>
        </div>
        <div class="text-left sm:text-right">
          <p class="text-3xl font-semibold tabular-nums">
            {format_spot_rate(@rate)}
          </p>
          <p class="mt-1 text-xs text-base-content/60">
            Updated {format_spot_updated_at(@updated_at)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :details, :map, required: true

  def fx_details_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body gap-3 p-4">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          FX details
        </h3>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">Destination amount</span>
          <span class="font-medium tabular-nums">
            <%= if @details.destination_amount do %>
              {@details.destination_amount} {@details.destination_currency}
            <% else %>
              —
            <% end %>
          </span>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">FX fee</span>
          <span class="font-medium tabular-nums">
            <%= if @details.fx_fee do %>
              {@details.fx_fee} {@details.fx_fee_currency}
            <% else %>
              —
            <% end %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp counterparty_options(parties, nil), do: parties

  defp counterparty_options(parties, originator_party_id),
    do: Enum.reject(parties, &(&1.id == originator_party_id))

  defp selected_originator(parties, party_id), do: Enum.find(parties, &(&1.id == party_id))

  defp selected_counterparty(parties, selected_counterparty_ids),
    do: Enum.find(parties, &(&1.id in selected_counterparty_ids))

  defp selected_party_name(parties, party_id)
       when is_binary(party_id) or is_integer(party_id),
       do: party_name(parties, party_id)

  defp selected_party_name(parties, [party_id | _]),
    do: party_name(parties, party_id)

  defp selected_party_name(_parties, _no_selection), do: "Not selected"

  defp party_name(parties, party_id) do
    case Enum.find(parties, &(&1.id == party_id)) do
      nil -> "Not selected"
      party -> party.legal_name
    end
  end

  defp fx_details(%{quote: quote}) when not is_nil(quote) do
    lines = (quote.calculation_snapshot || %{})["lines"] || []
    fee_line = Enum.find(lines, &(&1["code"] == "fx_fee"))

    %{
      destination_amount: quote.amount_in_counterparty_currency,
      destination_currency: quote.counterparty_currency_code,
      fx_fee: fee_line && fee_line["amount"],
      fx_fee_currency: fee_line && fee_line["currency_code"]
    }
  end

  defp fx_details(assigns) do
    amount = quote_form_value(assigns.quote_form, :amount_in_originator_currency)
    rate = selected_spot_rate(assigns.spot_rates, assigns.quote_form)
    from_code = quote_form_value(assigns.quote_form, :originator_currency_code)
    to_code = quote_form_value(assigns.quote_form, :counterparty_currency_code)

    if is_nil(from_code) or is_nil(to_code) do
      nil
    else
      destination_amount = preview_destination_amount(amount, rate)
      fx_fee = preview_fx_fee(amount, rate)

      %{
        destination_amount: destination_amount,
        destination_currency: to_code,
        fx_fee: fx_fee,
        fx_fee_currency: from_code
      }
    end
  end

  defp preview_destination_amount(amount, rate) do
    with amount_str when not is_nil(amount_str) and amount_str != "" <- amount,
         {amount_dec, ""} <- parse_decimal(amount_str),
         rate when not is_nil(rate) <- rate,
         {rate_dec, ""} <- parse_decimal(rate) do
      Decimal.mult(amount_dec, rate_dec) |> Decimal.round(2)
    else
      _ -> nil
    end
  end

  defp preview_fx_fee(amount, rate) do
    with amount_str when not is_nil(amount_str) and amount_str != "" <- amount,
         {amount_dec, ""} <- parse_decimal(amount_str),
         rate when not is_nil(rate) <- rate,
         {rate_dec, ""} <- parse_decimal(rate) do
      if Decimal.equal?(rate_dec, Decimal.new("1")) do
        Decimal.new("0")
      else
        Decimal.mult(amount_dec, Decimal.new("0.01"))
      end
    else
      _ -> nil
    end
  end

  defp parse_decimal(%Decimal{} = decimal), do: {decimal, ""}
  defp parse_decimal(value) when is_binary(value), do: Decimal.parse(value)
  defp parse_decimal(value), do: Decimal.parse(to_string(value))

  defp currency_options(currencies),
    do: for(currency <- currencies, do: {"#{currency.code} · #{currency.name}", currency.code})

  defp selected_spot_rate(rates, quote_form) do
    from_currency_code = quote_form_value(quote_form, :originator_currency_code)
    to_currency_code = quote_form_value(quote_form, :counterparty_currency_code)

    Map.get(rates, {from_currency_code, to_currency_code})
  end

  defp quote_form_value(quote_form, field) do
    Phoenix.HTML.Form.input_value(quote_form, field)
  end

  defp format_spot_rate(nil), do: "Waiting for rate"
  defp format_spot_rate(%Decimal{} = rate), do: Decimal.to_string(rate, :normal)
  defp format_spot_rate(rate), do: to_string(rate)

  defp spot_rate_input_value(nil), do: nil
  defp spot_rate_input_value(%Decimal{} = rate), do: Decimal.to_string(rate, :normal)
  defp spot_rate_input_value(rate), do: to_string(rate)

  defp format_spot_updated_at(nil), do: "on next tick"

  defp format_spot_updated_at(%DateTime{} = updated_at) do
    Calendar.strftime(updated_at, "%H:%M:%S UTC")
  end

  defp party_card_classes(true),
    do: base_party_card_classes() ++ ["border-primary bg-primary/10"]

  defp party_card_classes(false),
    do: base_party_card_classes() ++ ["border-base-300 bg-base-100"]

  defp base_party_card_classes,
    do: ["rounded-box border p-4 text-left transition hover:border-primary hover:bg-base-200"]
end
