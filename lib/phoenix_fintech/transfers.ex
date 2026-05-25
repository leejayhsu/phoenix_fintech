defmodule PhoenixFintech.Transfers do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Transfers.{FXQuote, Transfer}

  def list_transfers do
    Repo.all(
      from t in Transfer,
        order_by: [desc: t.inserted_at],
        preload: [:originator_party, :counterparty_party, :created_by_user, :fx_quote]
    )
  end

  def get_transfer!(id) do
    Repo.get!(Transfer, id)
    |> Repo.preload([:originator_party, :counterparty_party, :created_by_user, :fx_quote])
  end

  def change_transfer(attrs \\ %{}) do
    Transfer.changeset(%Transfer{}, attrs)
  end

  def create_transfer(user_id, attrs) do
    transfer_attrs = derive_amounts(attrs)
    quote_attrs = Map.get(attrs, "fx_quote", %{})

    Multi.new()
    |> maybe_insert_fx_quote(quote_attrs)
    |> Multi.insert(:transfer, fn changes ->
      transfer_params =
        transfer_attrs
        |> Map.put("created_by_user_id", user_id)
        |> maybe_put_fx_quote_id(changes)

      Transfer.changeset(%Transfer{}, transfer_params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transfer: transfer}} -> {:ok, get_transfer!(transfer.id)}
      {:error, step, changeset, changes} -> {:error, step, changeset, changes}
    end
  end

  defp maybe_insert_fx_quote(multi, %{} = attrs) when attrs == %{}, do: multi

  defp maybe_insert_fx_quote(multi, attrs) do
    Multi.insert(multi, :fx_quote, FXQuote.changeset(%FXQuote{}, attrs))
  end

  defp maybe_put_fx_quote_id(attrs, %{fx_quote: fx_quote}), do: Map.put(attrs, "fx_quote_id", fx_quote.id)
  defp maybe_put_fx_quote_id(attrs, _changes), do: attrs

  defp derive_amounts(attrs) do
    originator_amount = blank_to_nil(Map.get(attrs, "amount_in_originator_currency"))
    counterparty_amount = blank_to_nil(Map.get(attrs, "amount_in_counterparty_currency"))

    if not is_nil(originator_amount) and not is_nil(counterparty_amount) do
      attrs
    else
      rate =
        attrs
        |> Map.get("fx_quote", %{})
        |> Map.get("rate")
        |> blank_to_nil()

      cond do
        is_nil(rate) ->
          attrs

        not is_nil(originator_amount) ->
          Map.put(attrs, "amount_in_counterparty_currency", Decimal.mult(Decimal.new(originator_amount), Decimal.new(rate)))

        not is_nil(counterparty_amount) ->
          Map.put(attrs, "amount_in_originator_currency", Decimal.div(Decimal.new(counterparty_amount), Decimal.new(rate)))

        true ->
          attrs
      end
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
