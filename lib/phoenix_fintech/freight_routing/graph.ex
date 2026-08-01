defmodule PhoenixFintech.FreightRouting.Graph do
  @moduledoc """
  Mock maritime network used by the freight routing proof of concept.

  Distances, durations, and fuel consumption are illustrative estimates for a
  representative container vessel, not suitable for operational planning.
  """

  @ports [
    %{
      id: "los_angeles",
      name: "Port of Los Angeles",
      country: "United States",
      coordinates: [-118.264, 33.732]
    },
    %{
      id: "new_york",
      name: "Port of New York and New Jersey",
      country: "United States",
      coordinates: [-74.04, 40.67]
    },
    %{
      id: "manzanillo",
      name: "Port of Manzanillo",
      country: "Mexico",
      coordinates: [-104.316, 19.05]
    },
    %{id: "panama", name: "Panama Canal", country: "Panama", coordinates: [-79.68, 9.08]},
    %{id: "santos", name: "Port of Santos", country: "Brazil", coordinates: [-46.329, -23.961]},
    %{
      id: "buenos_aires",
      name: "Port of Buenos Aires",
      country: "Argentina",
      coordinates: [-58.37, -34.58]
    },
    %{
      id: "rotterdam",
      name: "Port of Rotterdam",
      country: "Netherlands",
      coordinates: [4.14, 51.95]
    },
    %{id: "hamburg", name: "Port of Hamburg", country: "Germany", coordinates: [9.93, 53.54]},
    %{id: "algeciras", name: "Port of Algeciras", country: "Spain", coordinates: [-5.44, 36.13]},
    %{id: "suez", name: "Suez Canal", country: "Egypt", coordinates: [32.55, 30.45]},
    %{
      id: "jebel_ali",
      name: "Port of Jebel Ali",
      country: "United Arab Emirates",
      coordinates: [55.03, 25.01]
    },
    %{
      id: "cape_town",
      name: "Port of Cape Town",
      country: "South Africa",
      coordinates: [18.44, -33.9]
    },
    %{id: "mumbai", name: "Jawaharlal Nehru Port", country: "India", coordinates: [72.95, 18.95]},
    %{
      id: "singapore",
      name: "Port of Singapore",
      country: "Singapore",
      coordinates: [103.84, 1.264]
    },
    %{id: "port_klang", name: "Port Klang", country: "Malaysia", coordinates: [101.36, 2.99]},
    %{
      id: "hong_kong",
      name: "Port of Hong Kong",
      country: "Hong Kong",
      coordinates: [114.15, 22.29]
    },
    %{
      id: "kaohsiung",
      name: "Port of Kaohsiung",
      country: "Taiwan",
      coordinates: [120.29, 22.61]
    },
    %{id: "shanghai", name: "Port of Shanghai", country: "China", coordinates: [121.474, 31.23]},
    %{id: "busan", name: "Port of Busan", country: "South Korea", coordinates: [129.04, 35.1]},
    %{id: "tokyo", name: "Port of Tokyo", country: "Japan", coordinates: [139.79, 35.62]}
  ]

  # Fuel is metric tonnes of very-low-sulphur fuel oil. Canal fees are mock USD.
  # Direct express services assume higher sailing speeds, so they can burn more
  # fuel than slower multi-hub alternatives despite covering fewer miles.
  @edges [
    %{
      from: "los_angeles",
      to: "manzanillo",
      distance_nm: 1_220,
      duration_hours: 78,
      fuel_tonnes: 125,
      canal_fee_usd: 0
    },
    %{
      from: "los_angeles",
      to: "tokyo",
      distance_nm: 4_840,
      duration_hours: 290,
      fuel_tonnes: 510,
      canal_fee_usd: 0
    },
    %{
      from: "los_angeles",
      to: "shanghai",
      distance_nm: 5_700,
      duration_hours: 310,
      fuel_tonnes: 700,
      canal_fee_usd: 0,
      service_surcharge_usd_per_container: 700
    },
    %{
      from: "los_angeles",
      to: "busan",
      distance_nm: 5_200,
      duration_hours: 300,
      fuel_tonnes: 650,
      canal_fee_usd: 0
    },
    %{
      from: "los_angeles",
      to: "hong_kong",
      distance_nm: 6_300,
      duration_hours: 350,
      fuel_tonnes: 820,
      canal_fee_usd: 0
    },
    %{
      from: "los_angeles",
      to: "singapore",
      distance_nm: 7_600,
      duration_hours: 430,
      fuel_tonnes: 960,
      canal_fee_usd: 0
    },
    %{
      from: "manzanillo",
      to: "panama",
      distance_nm: 1_430,
      duration_hours: 92,
      fuel_tonnes: 150,
      canal_fee_usd: 0
    },
    %{
      from: "panama",
      to: "new_york",
      distance_nm: 2_050,
      duration_hours: 132,
      fuel_tonnes: 220,
      canal_fee_usd: 420_000
    },
    %{
      from: "panama",
      to: "santos",
      distance_nm: 3_650,
      duration_hours: 230,
      fuel_tonnes: 390,
      canal_fee_usd: 420_000
    },
    %{
      from: "new_york",
      to: "rotterdam",
      distance_nm: 3_330,
      duration_hours: 205,
      fuel_tonnes: 350,
      canal_fee_usd: 0
    },
    %{
      from: "new_york",
      to: "santos",
      distance_nm: 4_100,
      duration_hours: 255,
      fuel_tonnes: 430,
      canal_fee_usd: 0
    },
    %{
      from: "new_york",
      to: "algeciras",
      distance_nm: 3_200,
      duration_hours: 190,
      fuel_tonnes: 570,
      canal_fee_usd: 0
    },
    %{
      from: "santos",
      to: "buenos_aires",
      distance_nm: 1_060,
      duration_hours: 74,
      fuel_tonnes: 115,
      canal_fee_usd: 0
    },
    %{
      from: "santos",
      to: "cape_town",
      distance_nm: 3_650,
      duration_hours: 225,
      fuel_tonnes: 385,
      canal_fee_usd: 0
    },
    %{
      from: "santos",
      to: "rotterdam",
      distance_nm: 5_300,
      duration_hours: 320,
      fuel_tonnes: 850,
      canal_fee_usd: 0
    },
    %{
      from: "santos",
      to: "algeciras",
      distance_nm: 4_300,
      duration_hours: 270,
      fuel_tonnes: 550,
      canal_fee_usd: 0
    },
    %{
      from: "buenos_aires",
      to: "cape_town",
      distance_nm: 3_750,
      duration_hours: 235,
      fuel_tonnes: 400,
      canal_fee_usd: 0
    },
    %{
      from: "rotterdam",
      to: "hamburg",
      distance_nm: 280,
      duration_hours: 28,
      fuel_tonnes: 34,
      canal_fee_usd: 0
    },
    %{
      from: "rotterdam",
      to: "algeciras",
      distance_nm: 1_320,
      duration_hours: 88,
      fuel_tonnes: 145,
      canal_fee_usd: 0
    },
    %{
      from: "algeciras",
      to: "suez",
      distance_nm: 1_950,
      duration_hours: 122,
      fuel_tonnes: 205,
      canal_fee_usd: 0
    },
    %{
      from: "algeciras",
      to: "cape_town",
      distance_nm: 5_250,
      duration_hours: 322,
      fuel_tonnes: 545,
      canal_fee_usd: 0
    },
    %{
      from: "suez",
      to: "jebel_ali",
      distance_nm: 2_480,
      duration_hours: 156,
      fuel_tonnes: 260,
      canal_fee_usd: 520_000
    },
    %{
      from: "suez",
      to: "mumbai",
      distance_nm: 3_250,
      duration_hours: 200,
      fuel_tonnes: 340,
      canal_fee_usd: 520_000
    },
    %{
      from: "cape_town",
      to: "jebel_ali",
      distance_nm: 4_150,
      duration_hours: 255,
      fuel_tonnes: 430,
      canal_fee_usd: 0
    },
    %{
      from: "cape_town",
      to: "mumbai",
      distance_nm: 4_600,
      duration_hours: 278,
      fuel_tonnes: 475,
      canal_fee_usd: 0
    },
    %{
      from: "cape_town",
      to: "singapore",
      distance_nm: 5_350,
      duration_hours: 325,
      fuel_tonnes: 555,
      canal_fee_usd: 0
    },
    %{
      from: "jebel_ali",
      to: "mumbai",
      distance_nm: 1_050,
      duration_hours: 70,
      fuel_tonnes: 115,
      canal_fee_usd: 0
    },
    %{
      from: "mumbai",
      to: "singapore",
      distance_nm: 2_450,
      duration_hours: 154,
      fuel_tonnes: 260,
      canal_fee_usd: 0
    },
    %{
      from: "singapore",
      to: "port_klang",
      distance_nm: 210,
      duration_hours: 22,
      fuel_tonnes: 28,
      canal_fee_usd: 0
    },
    %{
      from: "singapore",
      to: "hong_kong",
      distance_nm: 1_450,
      duration_hours: 94,
      fuel_tonnes: 155,
      canal_fee_usd: 0
    },
    %{
      from: "port_klang",
      to: "hong_kong",
      distance_nm: 1_520,
      duration_hours: 100,
      fuel_tonnes: 165,
      canal_fee_usd: 0
    },
    %{
      from: "port_klang",
      to: "shanghai",
      distance_nm: 2_100,
      duration_hours: 125,
      fuel_tonnes: 320,
      canal_fee_usd: 0
    },
    %{
      from: "singapore",
      to: "shanghai",
      distance_nm: 2_050,
      duration_hours: 118,
      fuel_tonnes: 300,
      canal_fee_usd: 0
    },
    %{
      from: "hong_kong",
      to: "kaohsiung",
      distance_nm: 360,
      duration_hours: 30,
      fuel_tonnes: 40,
      canal_fee_usd: 0
    },
    %{
      from: "hong_kong",
      to: "shanghai",
      distance_nm: 820,
      duration_hours: 58,
      fuel_tonnes: 90,
      canal_fee_usd: 0
    },
    %{
      from: "kaohsiung",
      to: "shanghai",
      distance_nm: 520,
      duration_hours: 40,
      fuel_tonnes: 58,
      canal_fee_usd: 0
    },
    %{
      from: "shanghai",
      to: "busan",
      distance_nm: 520,
      duration_hours: 42,
      fuel_tonnes: 60,
      canal_fee_usd: 0
    },
    %{
      from: "shanghai",
      to: "tokyo",
      distance_nm: 950,
      duration_hours: 62,
      fuel_tonnes: 155,
      canal_fee_usd: 0
    },
    %{
      from: "hong_kong",
      to: "tokyo",
      distance_nm: 1_550,
      duration_hours: 95,
      fuel_tonnes: 260,
      canal_fee_usd: 0
    },
    %{
      from: "busan",
      to: "tokyo",
      distance_nm: 640,
      duration_hours: 48,
      fuel_tonnes: 70,
      canal_fee_usd: 0
    },
    %{
      from: "tokyo",
      to: "panama",
      distance_nm: 7_680,
      duration_hours: 450,
      fuel_tonnes: 780,
      canal_fee_usd: 0
    }
  ]

  def ports, do: @ports
  def edges, do: @edges

  def port(id), do: Enum.find(@ports, &(&1.id == id))

  def neighbors(port_id) do
    Enum.flat_map(@edges, fn edge ->
      cond do
        edge.from == port_id -> [{edge.to, edge}]
        edge.to == port_id -> [{edge.from, edge}]
        true -> []
      end
    end)
  end
end
