defmodule PhoenixFintech.Transfers.Quotes.Pipeline do
  @moduledoc """
  Runs transfer quote item modules over a quote context.
  """

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  def run(%QuoteContext{} = ctx, items) when is_list(items) do
    items = Enum.map(items, &expand_item/1)
    ctx = QuoteContext.put_metadata(ctx, :item_order, items)

    Enum.reduce_while(items, {:ok, ctx}, fn item, {:ok, ctx} ->
      case missing_requirement(ctx, item) do
        nil ->
          apply_item(item, ctx)

        key ->
          {:halt, {:error, {item, {:missing_requirement, key}, ctx}}}
      end
    end)
  end

  defp expand_item(item) when is_atom(item), do: item

  defp apply_item(item, ctx) do
    case item.apply(ctx) do
      {:ok, %QuoteContext{} = ctx} -> {:cont, {:ok, ctx}}
      {:error, reason} -> {:halt, {:error, {item, reason, ctx}}}
    end
  end

  defp missing_requirement(ctx, item) do
    if function_exported?(item, :requires, 0) do
      item.requires()
      |> Enum.find(&(not QuoteContext.has_fact?(ctx, &1)))
    end
  end
end
