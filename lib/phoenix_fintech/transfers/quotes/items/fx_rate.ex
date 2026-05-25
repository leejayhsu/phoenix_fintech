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
      |> QuoteContext.put_fact(:fx_rate, Decimal.new("1"))
      |> QuoteContext.put_fact(:amount_in_counterparty_currency, amount)

    {:ok, ctx}
  end

  def apply(%QuoteContext{input: input} = ctx) do
    rate = Map.get(input, :fx_rate)

    if is_nil(rate) do
      {:error, :missing_fx_rate}
    else
      counterparty_amount =
        input.amount_in_originator_currency
        |> Decimal.mult(rate)
        |> Decimal.round(2)

      line = %{
        code: :fx_rate,
        type: :rate,
        currency_code: input.counterparty_currency_code,
        amount: Decimal.new("0"),
        label: "FX rate",
        source: __MODULE__,
        metadata: %{rate: rate}
      }

      ctx =
        ctx
        |> QuoteContext.put_fact(:fx_rate, rate)
        |> QuoteContext.put_fact(:amount_in_counterparty_currency, counterparty_amount)
        |> QuoteContext.add_line(line)

      {:ok, ctx}
    end
  end
end
