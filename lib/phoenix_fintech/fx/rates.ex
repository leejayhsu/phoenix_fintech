defmodule PhoenixFintech.Fx.Rates do
  @moduledoc """
  Realistic FX spot rate helpers.

  Rates are anchored to approximate USD mid-market values. Cross rates are
  derived via triangular arbitrage so that all pairs stay internally
  consistent.

  The numbers are ballpark figures suitable for demo/learning purposes and
  should not be used for real trading decisions.
  """

  # Rates expressed as "units of foreign currency per 1 USD" (USD/XXX).
  @usd_rates %{
    "USD" => Decimal.new("1"),
    "EUR" => Decimal.new("0.877"),
    "GBP" => Decimal.new("0.752"),
    "JPY" => Decimal.new("148"),
    "CNY" => Decimal.new("7.20"),
    "BRL" => Decimal.new("5.75"),
    "MXN" => Decimal.new("20.5")
  }

  @doc """
  Returns the set of currency codes for which a USD anchor rate is known.
  """
  def known_currency_codes, do: Map.keys(@usd_rates)

  @doc """
  Returns a map of all spot rates for the given currency codes.

  The map keys are `{from_code, to_code}` tuples and the values are
  `Decimal` rates. Identity pairs return `1`.
  """
  def spot_rates(currency_codes) do
    Map.new(
      for from_code <- currency_codes,
          to_code <- currency_codes do
        {{from_code, to_code}, spot_rate(from_code, to_code)}
      end
    )
  end

  @doc """
  Returns the mid-market spot rate from one currency to another.

  Raises if either currency is not in the configured USD anchor table.
  """
  def spot_rate(currency_code, currency_code), do: Decimal.new("1")

  def spot_rate(from_currency_code, to_currency_code) do
    usd_from = Map.fetch!(@usd_rates, from_currency_code)
    usd_to = Map.fetch!(@usd_rates, to_currency_code)

    # Cross rate: how many units of `to` one unit of `from` buys.
    usd_to
    |> Decimal.div(usd_from)
    |> Decimal.round(6)
  end

  @doc """
  Returns a live-style spot rate with a small random fluctuation applied.

  The fluctuation is up to ±0.03% to simulate streaming market ticks.
  """
  def live_spot_rate(from_currency_code, to_currency_code) do
    base = spot_rate(from_currency_code, to_currency_code)

    # Random integer between -3 and +3 basis points (0.01% each).
    basis_points = :rand.uniform(7) - 4
    fluctuation = basis_points |> Decimal.new() |> Decimal.div(Decimal.new("10000"))

    multiplier = Decimal.add(Decimal.new("1"), fluctuation)

    base
    |> Decimal.mult(multiplier)
    |> Decimal.round(6)
  end
end
