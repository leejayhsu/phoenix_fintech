defmodule PhoenixFintechWeb.PageController do
  use PhoenixFintechWeb, :controller

  alias PhoenixFintech.Transfers

  @compliance_statuses [
    "created",
    "originator_set",
    "counterparty_set",
    "fx_quote_confirmed",
    "compliance_review"
  ]
  @funding_statuses ["compliance_approved", "deposit_pending", "deposit_received"]
  @payout_statuses [
    "disbursement_pending",
    "disbursement_initiated",
    "disbursement_settled"
  ]
  def home(conn, _params) do
    case conn.assigns[:current_user] do
      %{id: user_id} -> render(conn, :home, dashboard: dashboard(user_id))
      _user -> render(conn, :home)
    end
  end

  defp dashboard(user_id) do
    transfers = Transfers.list_transfers_for_user(user_id)
    today = Date.utc_today()
    chart_dates = Enum.map(6..0//-1, &Date.add(today, -&1))

    today_transfers = Enum.filter(transfers, &(DateTime.to_date(&1.inserted_at) == today))
    spread_revenue = spread_revenue_chart(transfers, chart_dates)

    %{
      completed_transfers: Enum.count(transfers, &(&1.status == "completed")),
      total_transfers: length(transfers),
      today_transfer_count: length(today_transfers),
      today_volume: volume_by_currency(today_transfers),
      activity_chart: transfer_activity_chart(transfers, chart_dates),
      spread_revenue: spread_revenue,
      completion_chart: completion_chart(transfers, chart_dates),
      pipeline: [
        %{label: "Compliance", count: count_statuses(transfers, @compliance_statuses)},
        %{label: "Funding", count: count_statuses(transfers, @funding_statuses)},
        %{label: "Payout", count: count_statuses(transfers, @payout_statuses)},
        %{label: "Completed", count: count_statuses(transfers, ["completed"])}
      ],
      recent_transfers: Enum.take(transfers, 6)
    }
  end

  defp count_statuses(transfers, statuses),
    do: Enum.count(transfers, &(&1.status in statuses))

  defp volume_by_currency(transfers) do
    transfers
    |> Enum.group_by(& &1.originator_currency_code, & &1.amount_in_originator_currency)
    |> Enum.map(fn {currency_code, amounts} ->
      {currency_code, Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp transfer_activity_chart(transfers, dates) do
    counts = Enum.frequencies_by(transfers, &DateTime.to_date(&1.inserted_at))
    values = Enum.map(dates, &Map.get(counts, &1, 0))

    %{total: Enum.sum(values), points: chart_points(dates, values)}
  end

  defp completion_chart(transfers, dates) do
    completed_dates =
      for transfer <- transfers,
          event <- transfer.events,
          event.to_status == "completed",
          do: DateTime.to_date(event.occurred_at)

    counts = Enum.frequencies(completed_dates)
    values = Enum.map(dates, &Map.get(counts, &1, 0))

    %{total: Enum.sum(values), points: chart_points(dates, values)}
  end

  defp spread_revenue_chart(transfers, dates) do
    quoted_transfers = Enum.filter(transfers, & &1.transfer_quote)

    currency_code =
      quoted_transfers
      |> Enum.frequencies_by(& &1.transfer_quote.originator_currency_code)
      |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
      |> elem(0)

    revenue_by_date =
      quoted_transfers
      |> Enum.filter(&(&1.transfer_quote.originator_currency_code == currency_code))
      |> Enum.group_by(&DateTime.to_date(&1.inserted_at), & &1.transfer_quote.spread_amount)
      |> Map.new(fn {date, amounts} ->
        {date, Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2)}
      end)

    values = Enum.map(dates, &Map.get(revenue_by_date, &1, Decimal.new(0)))

    %{
      currency_code: currency_code,
      total: Enum.reduce(values, Decimal.new(0), &Decimal.add/2),
      points: chart_points(dates, values)
    }
  end

  defp chart_points(dates, values) do
    max_value = values |> Enum.map(&numeric_value/1) |> Enum.max(fn -> 0 end)

    Enum.zip_with(dates, values, fn date, value ->
      percent = if max_value == 0, do: 0, else: round(numeric_value(value) / max_value * 100)

      %{
        label: Calendar.strftime(date, "%a"),
        value: value,
        percent: percent
      }
    end)
  end

  defp numeric_value(%Decimal{} = value), do: Decimal.to_float(value)
  defp numeric_value(value), do: value
end
