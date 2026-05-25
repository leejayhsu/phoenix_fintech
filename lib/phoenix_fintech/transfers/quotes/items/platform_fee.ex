defmodule PhoenixFintech.Transfers.Quotes.Items.PlatformFee do
  @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  @fee Decimal.new("2.00")

  def apply(%QuoteContext{input: input} = ctx) do
    line = %{
      code: :platform_fee,
      type: :fee,
      currency_code: input.originator_currency_code,
      amount: @fee,
      label: "Platform fee",
      source: __MODULE__,
      metadata: %{}
    }

    {:ok, QuoteContext.add_line(ctx, line)}
  end
end
