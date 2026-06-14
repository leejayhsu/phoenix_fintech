defmodule PhoenixFintech.Transfers do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PhoenixFintech.Repo
  alias PhoenixFintech.Transfers.{Transfer, TransferQuote}
  alias PhoenixFintech.Transfers.Quotes.{Pipeline, QuoteContext}
  alias PhoenixFintech.Transfers.Quotes.Items

  @demo_fx_rates %{
    {"USD", "EUR"} => "0.9200",
    {"EUR", "USD"} => "1.0870",
    {"USD", "GBP"} => "0.7900",
    {"GBP", "USD"} => "1.2660",
    {"USD", "JPY"} => "156.2000",
    {"JPY", "USD"} => "0.0064",
    {"EUR", "GBP"} => "0.8600",
    {"GBP", "EUR"} => "1.1630"
  }

  def list_transfers do
    Repo.all(base_transfer_query())
  end

  def list_transfers_for_user(user_id) do
    Repo.all(
      from t in base_transfer_query(),
        where: t.created_by_user_id == ^user_id
    )
  end

  def get_transfer!(id) do
    Repo.get!(Transfer, id)
    |> Repo.preload([:originator_party, :counterparty_party, :created_by_user, :transfer_quote])
  end

  def change_transfer(attrs \\ %{}) do
    Transfer.changeset(%Transfer{}, attrs)
  end

  def create_transfer(user_id, attrs) do
    if quote_attrs?(attrs) do
      with {:ok, quote} <- quote_transfer(user_id, normalize_legacy_quote_attrs(attrs)) do
        create_transfer_from_quote(user_id, quote.id, %{
          "status" => Map.get(attrs, "status", "quoted")
        })
      end
    else
      transfer_attrs = derive_amounts(attrs)

      %Transfer{created_by_user_id: user_id}
      |> Transfer.changeset(transfer_attrs)
      |> Repo.insert()
      |> case do
        {:ok, transfer} -> {:ok, get_transfer!(transfer.id)}
        {:error, changeset} -> {:error, :transfer, changeset, %{}}
      end
    end
  end

  def quote_transfer(user_id, attrs) do
    input = normalize_quote_input(attrs)

    input
    |> QuoteContext.new()
    |> Pipeline.run(default_quote_items())
    |> case do
      {:ok, ctx} -> insert_transfer_quote(user_id, ctx)
      {:error, reason} -> {:error, :quote, reason, %{}}
    end
  end

  def get_transfer_quote!(id) do
    Repo.get!(TransferQuote, id)
    |> Repo.preload([:created_by_user, :originator_party, :counterparty_party])
  end

  def requote_transfer_quote(user_id, quote_id) do
    quote = get_transfer_quote!(quote_id)
    quote_transfer(user_id, quote.input_snapshot)
  end

  def create_transfer_from_quote(user_id, quote_id, attrs \\ %{}) do
    quote = get_transfer_quote!(quote_id)

    transfer_attrs =
      attrs
      |> Map.put("originator_party_id", quote.originator_party_id)
      |> Map.put("counterparty_party_id", quote.counterparty_party_id)
      |> Map.put("originator_currency_code", quote.originator_currency_code)
      |> Map.put("counterparty_currency_code", quote.counterparty_currency_code)
      |> Map.put("amount_in_originator_currency", quote.amount_in_originator_currency)
      |> Map.put("amount_in_counterparty_currency", quote.amount_in_counterparty_currency)
      |> Map.put("transfer_quote_id", quote.id)

    Multi.new()
    |> Multi.update(:quote, Ecto.Changeset.change(quote, accepted_at: DateTime.utc_now(:second)))
    |> Multi.insert(
      :transfer,
      Transfer.changeset(%Transfer{created_by_user_id: user_id}, transfer_attrs)
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{transfer: transfer}} -> {:ok, get_transfer!(transfer.id)}
      {:error, step, changeset, changes} -> {:error, step, changeset, changes}
    end
  end

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
          Map.put(
            attrs,
            "amount_in_counterparty_currency",
            Decimal.mult(Decimal.new(originator_amount), Decimal.new(rate))
          )

        not is_nil(counterparty_amount) ->
          Map.put(
            attrs,
            "amount_in_originator_currency",
            Decimal.div(Decimal.new(counterparty_amount), Decimal.new(rate))
          )

        true ->
          attrs
      end
    end
  end

  defp base_transfer_query do
    from t in Transfer,
      order_by: [desc: t.inserted_at],
      preload: [:originator_party, :counterparty_party, :created_by_user, :transfer_quote]
  end

  defp insert_transfer_quote(user_id, %QuoteContext{} = ctx) do
    attrs = %{
      "originator_party_id" => ctx.input.originator_party_id,
      "counterparty_party_id" => ctx.input.counterparty_party_id,
      "originator_currency_code" => ctx.input.originator_currency_code,
      "counterparty_currency_code" => ctx.input.counterparty_currency_code,
      "amount_in_originator_currency" => ctx.input.amount_in_originator_currency,
      "amount_in_counterparty_currency" => ctx.facts.amount_in_counterparty_currency,
      "input_snapshot" => snapshot(ctx.input),
      "calculation_snapshot" =>
        snapshot(%{
          facts: ctx.facts,
          lines: ctx.lines,
          totals: ctx.totals,
          metadata: ctx.metadata
        })
    }

    %TransferQuote{created_by_user_id: user_id}
    |> TransferQuote.changeset(attrs)
    |> Repo.insert()
  end

  defp default_quote_items do
    [
      Items.FXRate,
      Items.TransactionFee,
      Items.FXFee,
      Items.Discount,
      Items.PlatformFee
    ]
  end

  defp normalize_quote_input(attrs) do
    originator_currency_code = attrs |> Map.get("originator_currency_code") |> String.upcase()
    counterparty_currency_code = attrs |> Map.get("counterparty_currency_code") |> String.upcase()

    %{
      originator_party_id: Map.get(attrs, "originator_party_id"),
      counterparty_party_id: Map.get(attrs, "counterparty_party_id"),
      originator_currency_code: originator_currency_code,
      counterparty_currency_code: counterparty_currency_code,
      amount_in_originator_currency:
        attrs |> Map.get("amount_in_originator_currency") |> Decimal.new(),
      fx_rate:
        attrs
        |> Map.get("fx_rate")
        |> blank_to_nil()
        |> maybe_decimal()
        |> maybe_generated_fx_rate(originator_currency_code, counterparty_currency_code)
    }
  end

  defp maybe_generated_fx_rate(
         %Decimal{} = rate,
         _originator_currency_code,
         _counterparty_currency_code
       ),
       do: rate

  defp maybe_generated_fx_rate(nil, currency_code, currency_code), do: nil

  defp maybe_generated_fx_rate(nil, originator_currency_code, counterparty_currency_code) do
    @demo_fx_rates
    |> Map.get(
      {originator_currency_code, counterparty_currency_code},
      fallback_fx_rate(originator_currency_code, counterparty_currency_code)
    )
    |> Decimal.new()
  end

  defp fallback_fx_rate(originator_currency_code, counterparty_currency_code) do
    basis_points =
      (originator_currency_code <> counterparty_currency_code)
      |> String.to_charlist()
      |> Enum.sum()
      |> rem(7_000)
      |> Kernel.+(8_000)

    basis_points
    |> Decimal.new()
    |> Decimal.div(Decimal.new(10_000))
    |> Decimal.to_string(:normal)
  end

  defp normalize_legacy_quote_attrs(attrs) do
    fx_quote = Map.get(attrs, "fx_quote", %{})

    attrs
    |> Map.put_new("fx_rate", Map.get(fx_quote, "rate"))
  end

  defp quote_attrs?(attrs) do
    Map.has_key?(attrs, "fx_rate") or Map.has_key?(attrs, "fx_quote")
  end

  defp snapshot(value) when is_struct(value, Decimal), do: Decimal.to_string(value, :normal)
  defp snapshot(value) when is_atom(value), do: Atom.to_string(value)

  defp snapshot(value) when is_list(value) do
    Enum.map(value, &snapshot/1)
  end

  defp snapshot(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {snapshot_key(key), snapshot(value)} end)
  end

  defp snapshot(value), do: value

  defp snapshot_key(key) when is_atom(key), do: Atom.to_string(key)
  defp snapshot_key(key), do: key

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp maybe_decimal(nil), do: nil
  defp maybe_decimal(%Decimal{} = value), do: value
  defp maybe_decimal(value), do: Decimal.new(value)
end
