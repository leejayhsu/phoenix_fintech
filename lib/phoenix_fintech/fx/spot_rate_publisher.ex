defmodule PhoenixFintech.Fx.SpotRatePublisher do
  use GenServer

  alias PhoenixFintech.Fx.Rates
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
    currencies = Ledger.list_currencies(log: false)
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

  defp generated_rate(from_currency_code, to_currency_code) do
    Rates.live_spot_rate(from_currency_code, to_currency_code)
  end
end
