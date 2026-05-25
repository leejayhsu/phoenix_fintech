defmodule PhoenixFintech.Transfers.Quotes.Items.FXFee do
  @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  def requires, do: [:fx_rate]

  def apply(%QuoteContext{facts: %{fx_rate: rate}, input: input} = ctx) do
    if Decimal.equal?(rate, Decimal.new("1")) do
      {:ok, ctx}
    else
      amount = Decimal.mult(input.amount_in_originator_currency, Decimal.new("0.01"))

      line = %{
        code: :fx_fee,
        type: :fee,
        currency_code: input.originator_currency_code,
        amount: amount,
        label: "FX fee",
        source: __MODULE__,
        metadata: %{basis_points: 100}
      }

      {:ok, QuoteContext.add_line(ctx, line)}
    end
  end
end
