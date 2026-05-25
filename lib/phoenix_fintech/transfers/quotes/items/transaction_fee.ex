defmodule PhoenixFintech.Transfers.Quotes.Items.TransactionFee do
  @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  @fee Decimal.new("4.99")

  def apply(%QuoteContext{input: input} = ctx) do
    line = %{
      code: :transaction_fee,
      type: :fee,
      currency_code: input.originator_currency_code,
      amount: @fee,
      label: "Transaction fee",
      source: __MODULE__,
      metadata: %{}
    }

    {:ok, QuoteContext.add_line(ctx, line)}
  end
end
