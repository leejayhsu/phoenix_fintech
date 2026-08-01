defmodule PhoenixFintechWeb.FreightRoutingLive do
  use PhoenixFintechWeb, :live_view

  @route %{
    origin: "Shanghai, China",
    destination: "Santos, Brazil",
    estimated_days: 34,
    distance_nautical_miles: 11_300,
    ports: [
      %{
        name: "Port of Shanghai",
        country: "China",
        role: "Origin",
        coordinates: [121.4737, 31.2304]
      },
      %{
        name: "Port of Singapore",
        country: "Singapore",
        role: "Transshipment",
        coordinates: [103.84, 1.264]
      },
      %{
        name: "Port of Santos",
        country: "Brazil",
        role: "Destination",
        coordinates: [-46.3289, -23.9608]
      }
    ],
    geometry: [
      [121.4737, 31.2304],
      [122.5, 27.0],
      [119.0, 20.0],
      [113.0, 12.0],
      [106.0, 5.0],
      [103.84, 1.264],
      [96.0, -4.0],
      [86.0, -9.0],
      [74.0, -14.0],
      [62.0, -20.0],
      [50.0, -27.0],
      [39.0, -33.0],
      [29.0, -36.0],
      [19.0, -35.0],
      [8.0, -30.0],
      [-5.0, -26.0],
      [-19.0, -24.0],
      [-32.0, -24.0],
      [-42.0, -25.0],
      [-46.3289, -23.9608]
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page_title, "Freight Routing")
      |> assign(:route, @route)
      |> assign(:route_json, Jason.encode!(@route))
      |> assign_current_user()

    {:ok, socket}
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
            <span class="text-sm text-base-content/60">Ocean freight</span>
          </div>
          <h1 class="text-3xl font-semibold tracking-tight">Freight Routing</h1>
          <p class="mt-2 max-w-2xl text-base-content/70">
            Visualize the proposed journey, transshipment ports, and direction of travel.
          </p>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <div class="card card-border bg-base-100">
            <div class="card-body gap-1 p-5">
              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <.icon name="hero-map-pin" class="size-4" /> Origin
              </div>
              <div class="font-semibold">{@route.origin}</div>
            </div>
          </div>
          <div class="card card-border bg-base-100">
            <div class="card-body gap-1 p-5">
              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <.icon name="hero-flag" class="size-4" /> Destination
              </div>
              <div class="font-semibold">{@route.destination}</div>
            </div>
          </div>
          <div class="card card-border bg-base-100">
            <div class="card-body gap-1 p-5">
              <div class="flex items-center gap-2 text-sm text-base-content/60">
                <.icon name="hero-clock" class="size-4" /> Estimated transit
              </div>
              <div class="font-semibold">
                {@route.estimated_days} days · {format_number(@route.distance_nautical_miles)} nm
              </div>
            </div>
          </div>
        </div>

        <div class="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_18rem]">
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
                <h2 class="card-title text-lg">Port sequence</h2>
                <p class="mt-1 text-sm text-base-content/60">Shanghai to Santos via Singapore</p>
              </div>

              <ol id="freight-route-ports" class="space-y-0">
                <li
                  :for={{port, index} <- Enum.with_index(@route.ports)}
                  id={"freight-route-port-#{index}"}
                  class="relative flex gap-3 pb-6 last:pb-0"
                >
                  <div
                    :if={index < length(@route.ports) - 1}
                    class="absolute left-[0.6875rem] top-6 h-[calc(100%-1.5rem)] w-px bg-base-300"
                  >
                  </div>
                  <span class={[
                    "relative z-[1] mt-0.5 size-6 shrink-0 rounded-full border-4 border-base-100",
                    if(port.role == "Transshipment", do: "bg-accent", else: "bg-primary")
                  ]}>
                  </span>
                  <div class="min-w-0">
                    <div class="font-medium leading-tight">{port.name}</div>
                    <div class="mt-1 text-sm text-base-content/60">{port.country}</div>
                    <span class={[
                      "badge badge-sm badge-soft mt-2",
                      if(port.role == "Transshipment", do: "badge-accent", else: "badge-primary")
                    ]}>
                      {port.role}
                    </span>
                  </div>
                </li>
              </ol>
            </div>
          </aside>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp assign_current_user(socket) do
    assign(socket, :current_user, socket.assigns.current_scope.user)
  end
end
