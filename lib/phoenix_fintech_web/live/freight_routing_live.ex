defmodule PhoenixFintechWeb.FreightRoutingLive do
  use PhoenixFintechWeb, :live_view

  alias PhoenixFintech.FreightRouting

  @default_params %{
    "origin_id" => "shanghai",
    "destination_id" => "santos",
    "strategy" => "fastest"
  }

  @impl true
  def mount(_params, _session, socket) do
    ports = FreightRouting.list_ports()
    {:ok, route} = resolve_route(@default_params)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page_title, "Freight Routing")
      |> assign(:ports, ports)
      |> assign(:port_options, Enum.map(ports, &{"#{&1.name} · #{&1.country}", &1.id}))
      |> assign(:form, to_form(@default_params, as: :route))
      |> assign_route(route)
      |> assign_current_user()

    {:ok, socket}
  end

  @impl true
  def handle_event("resolve_route", %{"route" => params}, socket) do
    form = to_form(params, as: :route)

    case resolve_route(params) do
      {:ok, route} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> assign_route(route)
         |> push_event("route_changed", route)}

      {:error, :same_port} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Choose two different ports.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "No route is available for that selection.")}
    end
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
      <section id="freight-routing" class="mx-auto max-w-7xl space-y-5">
        <div>
          <div class="mb-2 flex items-center gap-2">
            <span class="badge badge-primary badge-soft">Indicative route</span>
            <span class="text-sm text-base-content/60">Mock ocean freight network</span>
          </div>
          <h1 class="text-3xl font-semibold tracking-tight">Freight Routing</h1>
          <p class="mt-2 max-w-3xl text-base-content/70">
            Compare deterministic routes across major ports using estimated sailing time or operating cost.
          </p>
        </div>

        <div class="card card-border bg-base-100">
          <.form
            for={@form}
            id="freight-route-form"
            phx-change="resolve_route"
            phx-submit="resolve_route"
            class="card-body gap-4 p-5"
          >
            <div class="grid items-end gap-4 lg:grid-cols-[1fr_auto_1fr]">
              <.input
                field={@form[:origin_id]}
                type="select"
                label="Origin"
                options={@port_options}
              />
              <div class="hidden pb-4 text-base-content/40 lg:block">
                <.icon name="hero-arrow-right" class="size-5" />
              </div>
              <.input
                field={@form[:destination_id]}
                type="select"
                label="Destination"
                options={@port_options}
              />
            </div>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Optimize route for</legend>
              <div class="join w-fit" id="freight-route-strategy">
                <input
                  type="radio"
                  name={@form[:strategy].name}
                  value="fastest"
                  aria-label="Fastest time"
                  class="btn join-item"
                  checked={@form[:strategy].value == "fastest"}
                />
                <input
                  type="radio"
                  name={@form[:strategy].name}
                  value="lowest_cost"
                  aria-label="Lowest cost"
                  class="btn join-item"
                  checked={@form[:strategy].value == "lowest_cost"}
                />
              </div>
            </fieldset>
          </.form>
        </div>

        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <.metric_card
            icon="hero-clock"
            label="Estimated transit"
            value={"#{format_number(@route.estimated_days)} days"}
          />
          <.metric_card
            icon="hero-map"
            label="Sailing distance"
            value={"#{format_number(@route.distance_nautical_miles)} nm"}
          />
          <.metric_card
            icon="hero-beaker"
            label="Vessel fuel estimate"
            value={"#{format_number(@route.fuel_tonnes)} tonnes"}
          />
          <.metric_card
            icon="hero-banknotes"
            label="Est. cost / container"
            value={format_currency_amount(@route.estimated_cost_usd, "USD")}
          />
        </div>

        <div class="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
          <div class="card card-border overflow-hidden bg-base-100">
            <div
              id="freight-route-map"
              phx-hook="ShippingMap"
              phx-update="ignore"
              data-route={@route_json}
              class="relative h-[30rem] w-full lg:h-[38rem]"
            >
              <div class="absolute inset-0 z-10 flex items-center justify-center bg-base-200">
                <span class="loading loading-spinner loading-lg text-primary"></span>
              </div>
            </div>
          </div>

          <aside class="card card-border bg-base-100">
            <div class="card-body gap-4 p-5">
              <div>
                <div class="flex items-center justify-between gap-2">
                  <h2 class="card-title text-lg">Route sequence</h2>
                  <span class="badge badge-primary badge-soft">
                    {strategy_label(@route.strategy)}
                  </span>
                </div>
                <p class="mt-1 text-sm text-base-content/60">
                  {@route.origin} to {@route.destination}
                </p>
              </div>

              <ol id="freight-route-ports" class="space-y-0">
                <li
                  :for={{port, index} <- Enum.with_index(@route.ports)}
                  id={"freight-route-port-#{index}"}
                  class="relative flex gap-3 pb-7 last:pb-0"
                >
                  <div
                    :if={index < length(@route.ports) - 1}
                    class="absolute left-[0.6875rem] top-6 h-[calc(100%-1.5rem)] w-px bg-base-300"
                  >
                  </div>
                  <span class={[
                    "relative z-[1] mt-0.5 size-6 shrink-0 rounded-full border-4 border-base-100",
                    if(port.role == "Waypoint", do: "bg-accent", else: "bg-primary")
                  ]}>
                  </span>
                  <div class="min-w-0 grow">
                    <div class="font-medium leading-tight">{port.name}</div>
                    <div class="mt-1 text-sm text-base-content/60">{port.country}</div>
                    <div
                      :if={leg = Enum.at(@route.legs, index)}
                      class="mt-2 rounded-box bg-base-200 p-2 text-xs text-base-content/70"
                    >
                      <div class="flex flex-wrap gap-x-3 gap-y-1">
                        <span>{format_number(leg.distance_nautical_miles)} nm</span>
                        <span>{format_duration(leg.duration_hours)}</span>
                        <span>{format_number(leg.fuel_tonnes)} t fuel</span>
                      </div>
                      <div :if={leg.canal_fee_usd > 0} class="mt-1 font-medium text-warning">
                        Vessel canal fee: {format_currency_amount(leg.canal_fee_usd, "USD")}
                      </div>
                      <div
                        :if={leg.service_surcharge_usd_per_container > 0}
                        class="mt-1 font-medium text-warning"
                      >
                        Express surcharge: {format_currency_amount(
                          leg.service_surcharge_usd_per_container,
                          "USD"
                        )} / container
                      </div>
                    </div>
                  </div>
                </li>
              </ol>

              <div class="alert alert-soft alert-info text-xs">
                <.icon name="hero-information-circle" class="size-5 shrink-0" />
                <span>
                  POC quote for one 40-foot container. Assumes an 8,000 TEU vessel at 85% utilization and fuel at $650 per tonne.
                </span>
              </div>
            </div>
          </aside>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp metric_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100">
      <div class="card-body gap-1 p-5">
        <div class="flex items-center gap-2 text-sm text-base-content/60">
          <.icon name={@icon} class="size-4" /> {@label}
        </div>
        <div class="font-semibold">{@value}</div>
      </div>
    </div>
    """
  end

  defp resolve_route(%{
         "origin_id" => origin_id,
         "destination_id" => destination_id,
         "strategy" => strategy
       }) do
    FreightRouting.resolve_route(origin_id, destination_id, strategy_atom(strategy))
  end

  defp resolve_route(_params), do: {:error, :invalid_route}

  defp strategy_atom("fastest"), do: :fastest
  defp strategy_atom("lowest_cost"), do: :lowest_cost
  defp strategy_atom(_strategy), do: :invalid

  defp strategy_label(:fastest), do: "Fastest"
  defp strategy_label(:lowest_cost), do: "Lowest cost"

  defp format_duration(hours) do
    days = div(hours, 24)
    remaining_hours = rem(hours, 24)

    case {days, remaining_hours} do
      {0, hours} -> "#{hours} hr"
      {days, 0} -> "#{days} d"
      {days, hours} -> "#{days} d #{hours} hr"
    end
  end

  defp assign_route(socket, route) do
    socket
    |> assign(:route, route)
    |> assign(:route_json, Jason.encode!(route))
  end

  defp assign_current_user(socket) do
    assign(socket, :current_user, socket.assigns.current_scope.user)
  end
end
