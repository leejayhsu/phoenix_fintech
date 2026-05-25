defmodule PhoenixFintech.Transfers.Quotes.QuoteItem do
  @moduledoc """
  Behaviour for transfer quote item modules.
  """

  alias PhoenixFintech.Transfers.Quotes.QuoteContext

  @callback apply(QuoteContext.t()) :: {:ok, QuoteContext.t()} | {:error, term()}
  @callback requires() :: [atom()]

  @optional_callbacks requires: 0
end
