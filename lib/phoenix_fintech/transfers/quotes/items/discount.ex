defmodule PhoenixFintech.Transfers.Quotes.Items.Discount do
  @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  def apply(%QuoteContext{input: input} = ctx) do
    line = %{
      code: :discount,
      type: :discount,
      currency_code: input.originator_currency_code,
      amount: Decimal.new("0.00"),
      label: "Discount",
      source: __MODULE__,
      metadata: %{}
    }

    {:ok, QuoteContext.add_line(ctx, line)}
  end
end
