defmodule PhoenixFintech.Fx.SpotRatePublisher do
  use GenServer

  alias PhoenixFintech.Ledger

  @topic "fx:spot_rates"
  @interval :timer.seconds(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(PhoenixFintech.PubSub, @topic)
  end

  def current_rates do
    GenServer.call(__MODULE__, :current_rates)
  end

  def current_snapshot do
    GenServer.call(__MODULE__, :current_snapshot)
  end

  def current_rate(from_currency_code, to_currency_code) do
    current_rates()
    |> Map.get({from_currency_code, to_currency_code})
  end

  @impl true
  def init(_state) do
    state = publish_rates()
    schedule_publish()

    {:ok, state}
  end

  @impl true
  def handle_call(:current_rates, _from, state) do
    {:reply, state.rates, state}
  end

  def handle_call(:current_snapshot, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:publish_rates, _state) do
    state = publish_rates()
    schedule_publish()

    {:noreply, state}
  end

  defp publish_rates do
    currencies = Ledger.list_currencies()
    updated_at = DateTime.utc_now(:second)
    rates = rates_for(currencies)

    Phoenix.PubSub.broadcast(PhoenixFintech.PubSub, @topic, {:spot_rates, rates, updated_at})

    %{rates: rates, updated_at: updated_at}
  end

  defp schedule_publish do
    Process.send_after(self(), :publish_rates, @interval)
  end

  defp rates_for(currencies) do
    currency_codes = Enum.map(currencies, & &1.code)

    Map.new(
      for from_currency_code <- currency_codes,
          to_currency_code <- currency_codes do
        {{from_currency_code, to_currency_code},
         generated_rate(from_currency_code, to_currency_code)}
      end
    )
  end

  defp generated_rate(currency_code, currency_code), do: Decimal.new("1")

  defp generated_rate(from_currency_code, to_currency_code) do
    base_basis_points =
      (from_currency_code <> to_currency_code)
      |> String.to_charlist()
      |> Enum.sum()
      |> rem(7_000)
      |> Kernel.+(8_000)

    basis_points = max(base_basis_points + :rand.uniform(101) - 51, 1)

    basis_points
    |> Decimal.new()
    |> Decimal.div(Decimal.new(10_000))
  end
end
