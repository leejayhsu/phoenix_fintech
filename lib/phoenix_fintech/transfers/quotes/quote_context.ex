defmodule PhoenixFintech.Transfers.Quotes.QuoteContext do
  @moduledoc """
  In-memory state transformed by transfer quote items.
  """

  @enforce_keys [:input]
  defstruct input: %{},
            entities: %{},
            facts: %{},
            lines: [],
            totals: %{},
            metadata: %{}

  def new(input, opts \\ []) when is_map(input) do
    %__MODULE__{
      input: input,
      entities: Keyword.get(opts, :entities, %{}),
      facts: Keyword.get(opts, :facts, %{}),
      lines: Keyword.get(opts, :lines, []),
      totals: Keyword.get(opts, :totals, %{}),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  def put_fact(%__MODULE__{} = ctx, key, value) when is_atom(key) do
    put_in(ctx.facts[key], value)
  end

  def has_fact?(%__MODULE__{} = ctx, key) when is_atom(key) do
    Map.has_key?(ctx.facts, key)
  end

  def add_line(%__MODULE__{} = ctx, line) when is_map(line) do
    %{ctx | lines: ctx.lines ++ [line]}
  end

  def put_total(%__MODULE__{} = ctx, key, value) when is_atom(key) do
    put_in(ctx.totals[key], value)
  end

  def put_metadata(%__MODULE__{} = ctx, key, value) when is_atom(key) do
    put_in(ctx.metadata[key], value)
  end
end
