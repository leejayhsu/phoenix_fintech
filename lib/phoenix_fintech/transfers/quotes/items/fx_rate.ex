defmodule PhoenixFintech.Transfers.Quotes.Items.FXRate do
  @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  def apply(
        %QuoteContext{
          input: %{originator_currency_code: currency, counterparty_currency_code: currency}
        } = ctx
      ) do
    amount = ctx.input.amount_in_originator_currency

    ctx =
      ctx
      |> QuoteContext.put_fact(:spot_fx_rate, Decimal.new("1"))
      |> QuoteContext.put_fact(:fx_rate, Decimal.new("1"))
      |> QuoteContext.put_fact(:spread_basis_points, 0)
      |> QuoteContext.put_fact(:spread_amount, Decimal.new("0"))
      |> QuoteContext.put_fact(:amount_in_counterparty_currency, amount)

    {:ok, ctx}
  end

  def apply(%QuoteContext{input: input} = ctx) do
    spot_rate = Map.get(input, :spot_fx_rate)

    if is_nil(spot_rate) do
      {:error, :missing_fx_rate}
    else
      spread_ratio = Decimal.div(input.spread_basis_points, 10_000)

      customer_rate =
        spot_rate
        |> Decimal.mult(Decimal.sub(1, spread_ratio))
        |> Decimal.round(6)

      spread_amount =
        input.amount_in_originator_currency
        |> Decimal.mult(spread_ratio)
        |> Decimal.round(2)

      counterparty_amount =
        input.amount_in_originator_currency
        |> Decimal.mult(customer_rate)
        |> Decimal.round(2)

      rate_line = %{
        code: :fx_rate,
        type: :rate,
        currency_code: input.counterparty_currency_code,
        amount: Decimal.new("0"),
        label: "Customer FX rate",
        source: __MODULE__,
        metadata: %{rate: customer_rate, spot_rate: spot_rate}
      }

      spread_line = %{
        code: :spread,
        type: :spread,
        currency_code: input.originator_currency_code,
        amount: spread_amount,
        label: "Creator spread",
        source: __MODULE__,
        metadata: %{
          basis_points: input.spread_basis_points,
          percentage: Decimal.mult(spread_ratio, 100)
        }
      }

      ctx =
        ctx
        |> QuoteContext.put_fact(:spot_fx_rate, spot_rate)
        |> QuoteContext.put_fact(:fx_rate, customer_rate)
        |> QuoteContext.put_fact(:spread_basis_points, input.spread_basis_points)
        |> QuoteContext.put_fact(:spread_amount, spread_amount)
        |> QuoteContext.put_fact(:amount_in_counterparty_currency, counterparty_amount)
        |> QuoteContext.add_line(rate_line)
        |> QuoteContext.add_line(spread_line)

      {:ok, ctx}
    end
  end
end
