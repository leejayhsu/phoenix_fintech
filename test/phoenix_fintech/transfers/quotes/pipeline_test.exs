defmodule PhoenixFintech.Transfers.Quotes.PipelineTest do
  use ExUnit.Case, async: true

  alias PhoenixFintech.Transfers.Quotes.{Pipeline, QuoteContext}

  defmodule AddFXRate do
    @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

    def apply(ctx) do
      {:ok, QuoteContext.put_fact(ctx, :fx_rate, Decimal.new("1.25"))}
    end
  end

  defmodule AddFXFee do
    @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

    def requires, do: [:fx_rate]

    def apply(ctx) do
      line = %{
        code: :fx_fee,
        type: :fee,
        currency_code: "USD",
        amount: Decimal.new("2.50"),
        label: "FX fee",
        source: __MODULE__,
        metadata: %{}
      }

      {:ok, QuoteContext.add_line(ctx, line)}
    end
  end

  defmodule NoOpDiscount do
    @behaviour PhoenixFintech.Transfers.Quotes.QuoteItem

    def apply(ctx), do: {:ok, ctx}
  end

  test "runs quote items in order and returns the updated context" do
    ctx = QuoteContext.new(%{amount: Decimal.new("100.00")})

    assert {:ok, quoted} = Pipeline.run(ctx, [AddFXRate, AddFXFee, NoOpDiscount])
    assert quoted.facts.fx_rate == Decimal.new("1.25")
    assert [%{code: :fx_fee, amount: amount}] = quoted.lines
    assert amount == Decimal.new("2.50")
    assert quoted.metadata.item_order == [AddFXRate, AddFXFee, NoOpDiscount]
  end

  test "halts when a required fact is missing" do
    ctx = QuoteContext.new(%{amount: Decimal.new("100.00")})

    assert {:error, {AddFXFee, {:missing_requirement, :fx_rate}, partial_ctx}} =
             Pipeline.run(ctx, [AddFXFee])

    assert partial_ctx.input == ctx.input
    assert partial_ctx.metadata.item_order == [AddFXFee]
  end
end
