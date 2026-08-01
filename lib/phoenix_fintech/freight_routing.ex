defmodule PhoenixFintech.FreightRouting do
  @moduledoc "Deterministic routing over the mock maritime network."

  alias PhoenixFintech.FreightRouting.Graph

  @fuel_price_usd_per_tonne 650
  @vessel_capacity_teu 8_000
  @vessel_utilization 0.85
  @teu_per_container 2
  @loaded_container_count round(@vessel_capacity_teu * @vessel_utilization / @teu_per_container)
  @daily_vessel_operating_cost_usd 45_000
  @handling_cost_per_leg_usd 225
  @booking_cost_usd 650
  @carrier_margin 1.2
  @strategies [:fastest, :lowest_cost]

  def list_ports, do: Graph.ports()

  def resolve_route(origin_id, destination_id, strategy)
      when strategy in @strategies and origin_id != destination_id do
    with %{id: ^origin_id} <- Graph.port(origin_id),
         %{id: ^destination_id} <- Graph.port(destination_id),
         {:ok, port_ids, edges} <- shortest_path(origin_id, destination_id, strategy) do
      {:ok, build_route(port_ids, edges, strategy)}
    else
      nil -> {:error, :unknown_port}
      {:error, _reason} = error -> error
    end
  end

  def resolve_route(port_id, port_id, strategy) when strategy in @strategies,
    do: {:error, :same_port}

  def resolve_route(_origin_id, _destination_id, _strategy), do: {:error, :invalid_route}

  defp shortest_path(origin_id, destination_id, strategy) do
    distances = %{origin_id => 0}
    visit(destination_id, strategy, distances, %{}, MapSet.new())
  end

  defp visit(destination_id, strategy, distances, previous, visited) do
    case next_unvisited(distances, visited) do
      nil ->
        {:error, :route_not_found}

      {^destination_id, _distance} ->
        {port_ids, edges} = reconstruct_path(destination_id, previous)
        {:ok, port_ids, edges}

      {current_id, current_distance} ->
        {distances, previous} =
          Enum.reduce(Graph.neighbors(current_id), {distances, previous}, fn {neighbor_id, edge},
                                                                             {distances, previous} ->
            candidate = current_distance + edge_weight(edge, strategy)

            if candidate < Map.get(distances, neighbor_id, :infinity) do
              {Map.put(distances, neighbor_id, candidate),
               Map.put(previous, neighbor_id, {current_id, edge})}
            else
              {distances, previous}
            end
          end)

        visit(destination_id, strategy, distances, previous, MapSet.put(visited, current_id))
    end
  end

  defp next_unvisited(distances, visited) do
    distances
    |> Enum.reject(fn {id, _distance} -> MapSet.member?(visited, id) end)
    |> Enum.min_by(fn {_id, distance} -> distance end, fn -> nil end)
  end

  defp reconstruct_path(destination_id, previous) do
    {port_ids, edges} =
      Stream.unfold(destination_id, fn current_id ->
        case Map.get(previous, current_id) do
          nil -> nil
          {prior_id, edge} -> {{prior_id, edge}, prior_id}
        end
      end)
      |> Enum.reduce({[destination_id], []}, fn {prior_id, edge}, {ids, edges} ->
        {[prior_id | ids], [edge | edges]}
      end)

    {port_ids, edges}
  end

  defp edge_weight(edge, :fastest), do: edge.duration_hours
  defp edge_weight(edge, :lowest_cost), do: estimated_container_leg_cost(edge)

  defp estimated_container_leg_cost(edge) do
    vessel_operating_cost =
      edge.fuel_tonnes * @fuel_price_usd_per_tonne +
        edge.canal_fee_usd +
        edge.duration_hours / 24 * @daily_vessel_operating_cost_usd

    vessel_operating_cost / @loaded_container_count +
      @handling_cost_per_leg_usd +
      Map.get(edge, :service_surcharge_usd_per_container, 0)
  end

  defp build_route(port_ids, edges, strategy) do
    ports =
      port_ids
      |> Enum.with_index()
      |> Enum.map(fn {id, index} ->
        role =
          cond do
            index == 0 -> "Origin"
            index == length(port_ids) - 1 -> "Destination"
            true -> "Waypoint"
          end

        Graph.port(id) |> Map.put(:role, role)
      end)

    legs =
      Enum.zip([port_ids, Enum.drop(port_ids, 1), edges])
      |> Enum.map(fn {from_id, to_id, edge} ->
        %{
          from: Graph.port(from_id).name,
          to: Graph.port(to_id).name,
          distance_nautical_miles: edge.distance_nm,
          duration_hours: edge.duration_hours,
          fuel_tonnes: edge.fuel_tonnes,
          canal_fee_usd: edge.canal_fee_usd,
          service_surcharge_usd_per_container:
            Map.get(edge, :service_surcharge_usd_per_container, 0),
          estimated_container_cost_usd: round(estimated_container_leg_cost(edge))
        }
      end)

    total_hours = Enum.sum(Enum.map(legs, & &1.duration_hours))
    container_leg_cost = Enum.sum(Enum.map(legs, & &1.estimated_container_cost_usd))

    %{
      origin: List.first(ports).name,
      destination: List.last(ports).name,
      strategy: strategy,
      estimated_days: Float.ceil(total_hours / 24, 1),
      duration_hours: total_hours,
      distance_nautical_miles: Enum.sum(Enum.map(legs, & &1.distance_nautical_miles)),
      fuel_tonnes: Enum.sum(Enum.map(legs, & &1.fuel_tonnes)),
      canal_fees_usd: Enum.sum(Enum.map(legs, & &1.canal_fee_usd)),
      estimated_cost_usd: round((container_leg_cost + @booking_cost_usd) * @carrier_margin),
      cost_basis: "per 40-foot container",
      ports: ports,
      legs: legs,
      geometry: Enum.map(ports, & &1.coordinates)
    }
  end
end
