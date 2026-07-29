defmodule PhoenixFintechWeb.HomeFxRatesLive do
  @moduledoc """
  Displays the latest non-identity FX rates and refreshes them from PubSub.
  """

  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.Fx.SpotRatePublisher

  @impl true
  def mount(_params, _session, socket) do
    snapshot = SpotRatePublisher.current_snapshot()

    if connected?(socket), do: SpotRatePublisher.subscribe()

    {:ok,
     socket
     |> assign(:updated_at, snapshot.updated_at)
     |> stream_configure(:rates, dom_id: &rate_dom_id/1)
     |> stream(:rates, display_rates(snapshot.rates))}
  end

  @impl true
  def handle_info({:spot_rates, rates, updated_at}, socket) do
    {:noreply,
     socket
     |> assign(:updated_at, updated_at)
     |> stream(:rates, display_rates(rates), reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section id="live-fx-rates" class="space-y-4">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-2 sm:flex-nowrap">
        <h2 class="text-2xl font-semibold tracking-tight">FX Rates</h2>
        <span class="badge badge-success badge-soft gap-1.5">
          <span class="size-1.5 rounded-full bg-success"></span> Live
        </span>
        <p class="text-sm text-base-content/60">Refreshes every 5 seconds.</p>
        <p class="ml-auto text-xs text-base-content/60 sm:text-right" aria-live="polite">
          Last tick {format_updated_at(@updated_at)}
        </p>
      </div>

      <div
        id="home-fx-rate-cards"
        phx-update="stream"
        class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6"
      >
        <article
          :for={{id, rate} <- @streams.rates}
          id={id}
          class="card card-border bg-base-200 shadow-sm"
        >
          <div class="card-body gap-3 p-4">
            <div class="flex items-center justify-between gap-3">
              <h3 class="font-semibold tracking-wide">{rate.from}/{rate.to}</h3>
              <.icon name="hero-arrows-right-left" class="size-4 text-primary" />
            </div>
            <div>
              <p class="text-xs text-base-content/50">1 {rate.from} buys</p>
              <p class="mt-0.5 flex items-baseline gap-1.5 tabular-nums">
                <span class="text-2xl font-semibold">{format_number(rate.value)}</span>
                <span class="text-sm font-medium text-base-content/60">{rate.to}</span>
              </p>
            </div>
          </div>
        </article>
      </div>
    </section>
    """
  end

  defp display_rates(rates) do
    rates
    |> Enum.filter(fn {{from, to}, _rate} -> from == "USD" and to != "USD" end)
    |> Enum.sort_by(fn {{from, to}, _rate} -> {from, to} end)
    |> Enum.map(fn {{from, to}, value} -> %{from: from, to: to, value: value} end)
  end

  defp rate_dom_id(%{from: from, to: to}), do: "fx-rate-#{from}-#{to}"

  defp format_updated_at(nil), do: "on the next update"

  defp format_updated_at(%DateTime{} = updated_at),
    do: Calendar.strftime(updated_at, "%H:%M:%S UTC")
end
