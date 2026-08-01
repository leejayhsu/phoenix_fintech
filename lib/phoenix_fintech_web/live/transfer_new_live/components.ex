defmodule PhoenixFintechWeb.TransferNewLive.Components do
  use PhoenixFintechWeb, :html

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :direction, :atom, default: nil

  def direction_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body mx-auto w-full max-w-3xl gap-6">
        <div>
          <h2 class="card-title">1. Choose direction</h2>
          <p class="text-sm text-base-content/70">
            Should the originator send funds to the counterparty, or receive funds from them?
          </p>
        </div>

        <div class="grid gap-3 md:grid-cols-2">
          <.direction_card
            direction="send"
            selected={@direction == :send}
            title="Send"
            description="The originator sends money to the counterparty."
            icon="hero-arrow-up"
          />
          <.direction_card
            direction="receive"
            selected={@direction == :receive}
            title="Receive"
            description="The counterparty sends money to the originator."
            icon="hero-arrow-down"
          />
        </div>
      </div>
    </section>
    """
  end

  attr :direction, :string, required: true
  attr :selected, :boolean, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true

  defp direction_card(assigns) do
    ~H"""
    <button
      type="button"
      id={"direction-card-#{@direction}"}
      phx-click="choose_direction"
      phx-value-direction={@direction}
      class={direction_card_classes(@selected)}
    >
      <span class="flex items-start gap-3">
        <.icon name={@icon} class="size-6 shrink-0" />
        <span class="text-left">
          <span class="block font-medium">{@title}</span>
          <span class="mt-1 block text-sm text-base-content/60">{@description}</span>
        </span>
      </span>
    </button>
    """
  end

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :direction, :atom, default: nil
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true

  def originator_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body mx-auto w-full max-w-3xl gap-6">
        <div>
          <h2 class="card-title">2. Choose the originator</h2>
          <p class="text-sm text-base-content/70">
            Select the party {originator_role_description(@direction)}.
          </p>
        </div>

        <div class="grid gap-3 md:grid-cols-2">
          <.party_card
            :for={party <- originator_options(@parties)}
            party={party}
            selected={party.id == @selected_originator_id}
            event="choose_originator"
            id_prefix="originator-party"
          />
        </div>

        <div :if={originator_options(@parties) == []} role="alert" class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>No parties are eligible to originate transfers yet.</span>
        </div>

        <div class="card-actions justify-between">
          <button
            type="button"
            id="back-to-direction-button"
            phx-click="go_to_step"
            phx-value-step="direction"
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
  attr :direction, :atom, required: true
  attr :parties, :list, required: true
  attr :selected_originator_id, :any, required: true
  attr :selected_counterparty_ids, :list, required: true

  def counterparties_step(assigns) do
    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body mx-auto w-full max-w-3xl gap-6">
        <div>
          <h2 class="card-title">3. Choose counterparty</h2>
          <p class="text-sm text-base-content/70">
            {counterparty_instruction(@direction)}
          </p>
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
  attr :reusable_quotes, :list, default: []
  attr :selected_reusable_quote_id, :string, default: nil

  def quote_step(assigns) do
    assigns =
      assign(
        assigns,
        :selected_reusable_quote,
        selected_reusable_quote(assigns.reusable_quotes, assigns.selected_reusable_quote_id)
      )

    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body gap-6">
        <div>
          <h2 class="card-title">4. Generate FX quote</h2>
        </div>

        <div :if={@quote_error} role="alert" class="alert alert-error alert-soft">
          <.icon name="hero-exclamation-circle" class="size-5" />
          <span>{@quote_error}</span>
        </div>

        <div class="rounded-box border border-base-300 bg-base-200/50 p-4">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="text-sm text-base-content/70">
                Apply a Day Quote, or continue with a fresh quote below.
              </p>
            </div>
            <.link navigate={~p"/app/quotes"} class="btn btn-ghost btn-sm shrink-0">
              Manage Day Quotes
            </.link>
          </div>

          <div
            :if={@reusable_quotes != []}
            id="reusable-quote-options"
            aria-label="Available Day Quotes"
            class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
          >
            <button
              :for={quote <- @reusable_quotes}
              id={"choose-day-quote-#{quote.id}"}
              type="button"
              aria-pressed={to_string(@selected_reusable_quote_id == quote.id)}
              phx-click="choose_reusable_quote"
              phx-value-id={quote.id}
              class={[
                "card card-sm cursor-pointer border text-left transition-colors hover:border-primary",
                @selected_reusable_quote_id == quote.id && "border-primary bg-primary/10",
                @selected_reusable_quote_id != quote.id && "border-base-300 bg-base-100"
              ]}
            >
              <span class="card-body gap-1">
                <span class="flex items-center justify-between gap-2">
                  <span class="font-semibold">
                    {quote.originator_currency_code}/{quote.counterparty_currency_code}
                  </span>
                  <.icon
                    :if={@selected_reusable_quote_id == quote.id}
                    name="hero-check-circle"
                    class="size-5 text-primary"
                  />
                </span>
                <span class="font-mono text-sm">
                  1 {quote.originator_currency_code} = {format_spot_rate(quote.customer_fx_rate)} {quote.counterparty_currency_code}
                </span>
                <span class="text-xs text-base-content/60">
                  {quote.spread_basis_points} bps spread
                </span>
              </span>
            </button>
          </div>

          <p :if={@reusable_quotes == []} class="mt-3 text-sm text-base-content/60">
            You have no active Day Quotes.
          </p>
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

              <.quote_terms_fields
                form={@quote_form}
                currencies={@currencies}
                disabled={not is_nil(@selected_reusable_quote)}
              />
            </div>

            <div class="space-y-4">
              <.spot_rate_card
                rate={
                  if(@selected_reusable_quote,
                    do: @selected_reusable_quote.customer_fx_rate,
                    else: selected_spot_rate(@spot_rates, @quote_form)
                  )
                }
                from_currency_code={quote_form_value(@quote_form, :originator_currency_code)}
                to_currency_code={quote_form_value(@quote_form, :counterparty_currency_code)}
                updated_at={@spot_rates_updated_at}
                live={is_nil(@selected_reusable_quote)}
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

  attr :form, Phoenix.HTML.Form, required: true
  attr :currencies, :list, required: true
  attr :currency_prompt, :string, default: nil
  attr :currency_codes_only, :boolean, default: false
  attr :stacked, :boolean, default: false
  attr :split, :boolean, default: false
  attr :disabled, :boolean, default: false

  def quote_terms_fields(assigns) do
    ~H"""
    <div class={[
      "[&_.fieldset]:mb-0",
      if(@split, do: "grid grid-cols-2 items-start gap-4", else: "space-y-4")
    ]}>
      <.input
        field={@form[:spread_basis_points]}
        type="number"
        min="0"
        max="9999"
        step="1"
        label="Spread (bps)"
        disabled={@disabled}
      />

      <div class={[
        "grid",
        cond do
          @split -> "gap-0"
          @stacked -> "gap-0"
          true -> "gap-4 sm:grid-cols-2"
        end
      ]}>
        <.input
          field={@form[:originator_currency_code]}
          type="select"
          label="Send currency"
          prompt={@currency_prompt}
          options={currency_options(@currencies, @currency_codes_only)}
          disabled={@disabled}
        />
        <.input
          field={@form[:counterparty_currency_code]}
          type="select"
          label="Destination currency"
          prompt={@currency_prompt}
          options={currency_options(@currencies, @currency_codes_only)}
          disabled={@disabled}
        />
      </div>
      <div :if={@disabled}>
        <input
          id="locked-spread-basis-points"
          type="hidden"
          name={@form[:spread_basis_points].name}
          value={@form[:spread_basis_points].value}
        />
        <input
          id="locked-originator-currency-code"
          type="hidden"
          name={@form[:originator_currency_code].name}
          value={@form[:originator_currency_code].value}
        />
        <input
          id="locked-counterparty-currency-code"
          type="hidden"
          name={@form[:counterparty_currency_code].name}
          value={@form[:counterparty_currency_code].value}
        />
      </div>
    </div>
    """
  end

  attr :panel_class, :any, required: true
  attr :active, :boolean, required: true
  attr :quote, :any, default: nil
  attr :quote_error, :string, default: nil
  attr :parties, :list, required: true
  attr :direction, :atom, default: nil
  attr :selected_originator_id, :any, required: true
  attr :selected_counterparty_ids, :list, required: true

  def review_step(assigns) do
    assigns = assign(assigns, review_summary(assigns))

    ~H"""
    <section class={@panel_class} inert={!@active}>
      <div class="card-body gap-6">
        <div>
          <h2 class="card-title">5. Review</h2>
          <p class="text-sm text-base-content/70">
            Confirm the binding FX quote and create the transfer for internal review.
          </p>
        </div>

        <div :if={@quote} class="grid gap-4 lg:grid-cols-[1.4fr_0.6fr]">
          <div class="card card-border bg-base-200">
            <div class="card-body gap-4 p-4">
              <div class="flex items-center justify-between gap-3">
                <h3 class="font-medium">Transfer summary</h3>
                <span class="badge badge-soft badge-primary">{format_direction(@direction)}</span>
              </div>

              <div class="grid items-stretch gap-3 md:grid-cols-[1fr_auto_1fr] md:gap-4">
                <div class="rounded-box bg-base-100 p-4">
                  <div class="flex items-center gap-2 text-sm text-base-content/60">
                    <span class="flex size-8 items-center justify-center rounded-full bg-primary/10 text-primary">
                      <.icon name="hero-arrow-up-right" class="size-4" />
                    </span>
                    Sender
                  </div>
                  <p class="mt-3 font-semibold">{@sender.legal_name}</p>
                  <div class="divider my-2"></div>
                  <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                    Send amount
                  </p>
                  <p class="mt-1 text-xl font-semibold tabular-nums">
                    {format_currency_amount(@send_amount, @send_currency_code)}
                  </p>
                </div>

                <div class="hidden items-center text-primary md:flex">
                  <.icon name="hero-arrow-right" class="size-6" />
                </div>
                <div class="flex justify-center text-primary md:hidden">
                  <.icon name="hero-arrow-down" class="size-6" />
                </div>

                <div class="rounded-box bg-base-100 p-4">
                  <div class="flex items-center gap-2 text-sm text-base-content/60">
                    <span class="flex size-8 items-center justify-center rounded-full bg-secondary/10 text-secondary">
                      <.icon name="hero-arrow-down-left" class="size-4" />
                    </span>
                    Recipient
                  </div>
                  <p class="mt-3 font-semibold">{@recipient.legal_name}</p>
                  <div class="divider my-2"></div>
                  <p class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                    Destination amount
                  </p>
                  <p class="mt-1 text-xl font-semibold tabular-nums">
                    {format_currency_amount(@destination_amount, @destination_currency_code)}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <.spot_rate_card
            rate={@quote.customer_fx_rate}
            from_currency_code={@quote.originator_currency_code}
            to_currency_code={@quote.counterparty_currency_code}
            vertical={true}
            show_badge={false}
          />
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
      class={["relative overflow-hidden", party_card_classes(@selected)]}
    >
      <img
        :if={@party.country_code}
        src={flag_url(@party.country_code)}
        alt=""
        aria-hidden="true"
        class="pointer-events-none absolute inset-y-0 -right-6 h-full w-2/3 scale-125 object-cover opacity-15 [mask-image:linear-gradient(to_right,transparent,black_35%)]"
      />
      <span class="relative z-10 flex items-start justify-between gap-3">
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
  attr :vertical, :boolean, default: false
  attr :live, :boolean, default: true
  attr :show_badge, :boolean, default: true

  def spot_rate_card(assigns) do
    assigns =
      assigns
      |> assign(:from_flag_url, currency_flag_url(assigns.from_currency_code))
      |> assign(:to_flag_url, currency_flag_url(assigns.to_currency_code))

    ~H"""
    <div class={[
      "card card-border bg-base-200 relative overflow-hidden",
      @vertical && "h-24",
      !@vertical && "mt-4"
    ]}>
      <img
        :if={@vertical && @from_flag_url}
        src={@from_flag_url}
        alt=""
        aria-hidden="true"
        class="pointer-events-none absolute inset-y-0 -left-4 h-full w-1/2 object-cover opacity-20 [mask-image:linear-gradient(to_right,black_0%,rgba(0,0,0,0.8)_20%,rgba(0,0,0,0.35)_50%,transparent_80%)]"
      />
      <img
        :if={@vertical && @to_flag_url}
        src={@to_flag_url}
        alt=""
        aria-hidden="true"
        class="pointer-events-none absolute inset-y-0 -right-4 h-full w-1/2 object-cover opacity-20 [mask-image:linear-gradient(to_left,black_0%,rgba(0,0,0,0.8)_20%,rgba(0,0,0,0.35)_50%,transparent_80%)]"
      />
      <div class={[
        "card-body relative z-10",
        @vertical && "h-full items-center justify-between px-4 py-3 text-center",
        !@vertical && "gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
      ]}>
        <div>
          <div class={[
            "flex items-center gap-2",
            @vertical && "flex-col"
          ]}>
            <span
              :if={@show_badge}
              class={[
                "badge badge-soft",
                if(@live, do: "badge-success", else: "badge-primary")
              ]}
            >
              {if(@live, do: "Live spot", else: "Day Quote")}
            </span>
            <span :if={!@vertical || !@show_badge} class="flex items-center">
              <span class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                {@from_currency_code}/{@to_currency_code}
              </span>
              <span
                :if={@live && @show_badge}
                class="tooltip tooltip-right text-base-content/60"
                data-tip="This rate refreshes every 5 seconds and will be locked when you generate the binding quote."
              >
                <.icon name="hero-information-circle" class="size-4" />
              </span>
            </span>
          </div>
        </div>
        <div class={[
          "text-left",
          @vertical && "text-center",
          !@vertical && "sm:text-right"
        ]}>
          <p class={[
            "font-semibold tabular-nums",
            cond do
              @vertical && is_nil(@rate) -> "text-2xl leading-none"
              @vertical -> "text-4xl leading-none"
              true -> "text-3xl"
            end
          ]}>
            {if(@vertical && is_nil(@rate), do: "Select pair", else: format_spot_rate(@rate))}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :details, :map, required: true

  def fx_details_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-200">
      <div class="card-body gap-3 p-4">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          FX details
        </h3>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">Customer rate</span>
          <span class="font-medium tabular-nums">
            {format_spot_rate(@details.customer_rate)}
          </span>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">Destination amount</span>
          <span class="font-medium tabular-nums">
            <%= if @details.destination_amount do %>
              {format_currency_amount(@details.destination_amount, @details.destination_currency)}
            <% else %>
              —
            <% end %>
          </span>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">
            Spread ({@details.spread_basis_points} bps)
          </span>
          <span class="font-medium tabular-nums">
            {format_currency_amount(@details.spread_amount, @details.spread_currency)}
          </span>
        </div>
        <div class="flex items-center justify-between gap-4">
          <span class="text-sm text-base-content/70">FX fee</span>
          <span class="font-medium tabular-nums">
            <%= if @details.fx_fee do %>
              {format_currency_amount(@details.fx_fee, @details.fx_fee_currency)}
            <% else %>
              —
            <% end %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp originator_options(parties), do: Enum.filter(parties, & &1.can_originate)

  defp counterparty_options(parties, nil), do: parties

  defp counterparty_options(parties, originator_party_id),
    do: Enum.reject(parties, &(&1.id == originator_party_id))

  defp selected_originator(parties, party_id), do: Enum.find(parties, &(&1.id == party_id))

  defp selected_counterparty(parties, selected_counterparty_ids),
    do: Enum.find(parties, &(&1.id in selected_counterparty_ids))

  defp originator_role_description(:receive), do: "who will receive the funds"
  defp originator_role_description(_direction), do: "who will send the funds"

  defp counterparty_instruction(:receive), do: "Choose the party who will send the funds."
  defp counterparty_instruction(_direction), do: "Select the party who will receive the funds."

  defp format_direction(:send), do: "Send"
  defp format_direction(:receive), do: "Receive"
  defp format_direction(_), do: "—"

  defp sender(:receive, parties, originator_id, counterparty_ids),
    do:
      selected_counterparty(parties, counterparty_ids) ||
        selected_originator(parties, originator_id)

  defp sender(_direction, parties, originator_id, _counterparty_ids),
    do: selected_originator(parties, originator_id)

  defp recipient(:receive, parties, originator_id, _counterparty_ids),
    do: selected_originator(parties, originator_id)

  defp recipient(_direction, parties, _originator_id, counterparty_ids),
    do: selected_counterparty(parties, counterparty_ids)

  defp review_summary(%{quote: nil}) do
    %{
      sender: nil,
      recipient: nil,
      send_amount: nil,
      send_currency_code: nil,
      destination_amount: nil,
      destination_currency_code: nil
    }
  end

  defp review_summary(assigns) do
    {send_amount, send_currency_code, destination_amount, destination_currency_code} =
      directional_amounts(assigns.direction, assigns.quote)

    %{
      sender:
        sender(
          assigns.direction,
          assigns.parties,
          assigns.selected_originator_id,
          assigns.selected_counterparty_ids
        ),
      recipient:
        recipient(
          assigns.direction,
          assigns.parties,
          assigns.selected_originator_id,
          assigns.selected_counterparty_ids
        ),
      send_amount: send_amount,
      send_currency_code: send_currency_code,
      destination_amount: destination_amount,
      destination_currency_code: destination_currency_code
    }
  end

  defp directional_amounts(:receive, quote) do
    {
      quote.amount_in_counterparty_currency,
      quote.counterparty_currency_code,
      quote.amount_in_originator_currency,
      quote.originator_currency_code
    }
  end

  defp directional_amounts(_direction, quote) do
    {
      quote.amount_in_originator_currency,
      quote.originator_currency_code,
      quote.amount_in_counterparty_currency,
      quote.counterparty_currency_code
    }
  end

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
      customer_rate: quote.customer_fx_rate,
      spread_basis_points: quote.spread_basis_points,
      spread_amount: quote.spread_amount,
      spread_currency: quote.originator_currency_code,
      fx_fee: fee_line && fee_line["amount"],
      fx_fee_currency: fee_line && fee_line["currency_code"]
    }
  end

  defp fx_details(assigns) do
    case selected_reusable_quote(assigns.reusable_quotes, assigns.selected_reusable_quote_id) do
      nil -> live_fx_details(assigns)
      quote -> reusable_quote_fx_details(quote)
    end
  end

  defp live_fx_details(assigns) do
    amount = quote_form_value(assigns.quote_form, :amount_in_originator_currency)
    rate = selected_spot_rate(assigns.spot_rates, assigns.quote_form)
    spread_basis_points = quote_form_value(assigns.quote_form, :spread_basis_points)
    from_code = quote_form_value(assigns.quote_form, :originator_currency_code)
    to_code = quote_form_value(assigns.quote_form, :counterparty_currency_code)

    if is_nil(from_code) or is_nil(to_code) do
      nil
    else
      identity_fx? = from_code == to_code
      effective_basis_points = if(identity_fx?, do: 0, else: spread_basis_points)
      customer_rate = preview_customer_rate(rate, effective_basis_points)
      destination_amount = preview_destination_amount(amount, customer_rate)
      fx_fee = preview_fx_fee(amount, rate)
      spread_amount = preview_spread_amount(amount, effective_basis_points)

      %{
        destination_amount: destination_amount,
        destination_currency: to_code,
        customer_rate: customer_rate,
        spread_basis_points: effective_basis_points,
        spread_amount: spread_amount,
        spread_currency: from_code,
        fx_fee: fx_fee,
        fx_fee_currency: from_code
      }
    end
  end

  defp reusable_quote_fx_details(quote) do
    %{
      destination_amount: quote.amount_in_counterparty_currency,
      destination_currency: quote.counterparty_currency_code,
      customer_rate: quote.customer_fx_rate,
      spread_basis_points: quote.spread_basis_points,
      spread_amount: quote.spread_amount,
      spread_currency: quote.originator_currency_code,
      fx_fee: nil,
      fx_fee_currency: quote.originator_currency_code
    }
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

  defp preview_customer_rate(rate, basis_points) do
    with rate when not is_nil(rate) <- rate,
         {rate_dec, ""} <- parse_decimal(rate),
         {basis_points, ""} <- Integer.parse(to_string(basis_points)),
         true <- basis_points >= 0 and basis_points < 10_000 do
      spread_ratio = Decimal.div(basis_points, 10_000)
      Decimal.mult(rate_dec, Decimal.sub(1, spread_ratio)) |> Decimal.round(6)
    else
      _ -> nil
    end
  end

  defp preview_spread_amount(amount, basis_points) do
    with amount when not is_nil(amount) and amount != "" <- amount,
         {amount_dec, ""} <- parse_decimal(amount),
         {basis_points, ""} <- Integer.parse(to_string(basis_points)),
         true <- basis_points >= 0 and basis_points < 10_000 do
      amount_dec
      |> Decimal.mult(Decimal.div(basis_points, 10_000))
      |> Decimal.round(2)
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

  defp currency_options(currencies, true),
    do: for(currency <- currencies, do: {currency.code, currency.code})

  defp currency_options(currencies, false),
    do: for(currency <- currencies, do: {"#{currency.code} · #{currency.name}", currency.code})

  defp selected_spot_rate(rates, quote_form) do
    from_currency_code = quote_form_value(quote_form, :originator_currency_code)
    to_currency_code = quote_form_value(quote_form, :counterparty_currency_code)

    Map.get(rates, {from_currency_code, to_currency_code})
  end

  defp selected_reusable_quote(reusable_quotes, quote_id),
    do: Enum.find(reusable_quotes, &(&1.id == quote_id))

  defp quote_form_value(quote_form, field) do
    Phoenix.HTML.Form.input_value(quote_form, field)
  end

  defp format_spot_rate(nil), do: "Waiting for rate"
  defp format_spot_rate(%Decimal{} = rate), do: Decimal.to_string(rate, :normal)
  defp format_spot_rate(rate), do: to_string(rate)

  defp spot_rate_input_value(nil), do: nil
  defp spot_rate_input_value(%Decimal{} = rate), do: Decimal.to_string(rate, :normal)
  defp spot_rate_input_value(rate), do: to_string(rate)

  defp flag_url(country_code),
    do: "https://flagcdn.com/#{String.downcase(country_code)}.svg"

  defp currency_flag_url(currency_code) do
    case currency_code do
      "USD" -> flag_url("US")
      "EUR" -> flag_url("EU")
      "GBP" -> flag_url("GB")
      "JPY" -> flag_url("JP")
      "CNY" -> flag_url("CN")
      "BRL" -> flag_url("BR")
      "MXN" -> flag_url("MX")
      _currency_code -> nil
    end
  end

  defp party_card_classes(true),
    do: base_party_card_classes() ++ ["border-primary bg-primary/10"]

  defp party_card_classes(false),
    do: base_party_card_classes() ++ ["border-base-300 bg-base-200"]

  defp direction_card_classes(true),
    do: base_party_card_classes() ++ ["border-primary bg-primary/10"]

  defp direction_card_classes(false),
    do: base_party_card_classes() ++ ["border-base-300 bg-base-200"]

  defp base_party_card_classes,
    do: ["rounded-box border p-4 text-left transition hover:border-primary hover:bg-base-200"]
end
