# Transfer Quotes Design

## Goal

Replace the FX-only quote model with a broader `transfer_quotes` model that can represent FX rate, transaction fee, FX fee, discount, platform fee, and future quote contributions through an idiomatic Elixir data-transformation pipeline.

## Decisions

- Replace `transfer_fx_quotes` with `transfer_quotes`.
- Store both immutable quote output and original recalculation input.
- Keep quote pipeline order and quote item logic code-defined for now.
- Model quote items as modules that implement a small `apply/1` contract.
- Keep quoting separate from transfer creation so a user can create/recalculate a quote before accepting it into a transfer.

## Architecture

Quote calculation lives under `PhoenixFintech.Transfers.Quotes`. The quote pipeline transforms a `%QuoteContext{}` through ordered quote item modules. Each quote item receives the context produced by previous items and returns either `{:ok, updated_context}` or `{:error, reason}`. Items that do not apply return the context unchanged.

The system uses modules and functions rather than objects. The `%QuoteContext{}` struct is the quote state, and item modules are named transformations over that state. A lightweight behaviour documents the callback contract and gives compile-time warnings if an item does not implement `apply/1`.

## Components

- `PhoenixFintech.Transfers.TransferQuote`: Ecto schema for persisted quote snapshots.
- `PhoenixFintech.Transfers.Quotes.QuoteContext`: in-memory struct containing input, loaded entities, facts, lines, totals, and metadata.
- `PhoenixFintech.Transfers.Quotes.QuoteItem`: behaviour for quote item modules.
- `PhoenixFintech.Transfers.Quotes.Pipeline`: ordered runner using `Enum.reduce_while/3`.
- `PhoenixFintech.Transfers.Quotes.Items.FXRate`: adds FX rate facts and counterparty amount calculation when currencies differ.
- `PhoenixFintech.Transfers.Quotes.Items.TransactionFee`: adds a fixed transaction fee.
- `PhoenixFintech.Transfers.Quotes.Items.FXFee`: adds an FX fee when an FX rate is present.
- `PhoenixFintech.Transfers.Quotes.Items.Discount`: applies code-defined discounts.
- `PhoenixFintech.Transfers.Quotes.Items.PlatformFee`: adds a platform fee.

## Quote Context

The context struct contains:

- `input`: normalized quote request fields such as amount, currencies, originator party id, counterparty party id, entity references, and user id.
- `entities`: loaded Ecto structs needed by quote items.
- `facts`: named intermediate results, such as `:fx_rate`, `:counterparty_amount`, and `:corridor`.
- `lines`: ordered quote contribution maps. Each line has a `code`, `type`, `currency_code`, `amount`, `label`, `source`, and `metadata`.
- `totals`: derived totals for originator debit amount, counterparty credit amount, fee total, discount total, and platform total.
- `metadata`: calculation metadata such as pipeline version and item order.

Dependencies between quote items are represented by context facts and pipeline order. A later item can require a fact from an earlier item and return a domain error if the fact is missing.

## Persistence

`transfer_quotes` stores immutable snapshots:

- transfer-facing request fields for querying and display.
- `input_snapshot` JSON for recalculation input.
- `calculation_snapshot` JSON for the quote output, including applied item order, facts, lines, totals, and metadata.
- optional `expires_at` and `accepted_at` timestamps.

Existing transfers reference `transfer_quotes` instead of `transfer_fx_quotes`. Accepted quotes should not be mutated. Requoting creates a new quote row from the stored `input_snapshot`.

## Public API

Add quote APIs to `PhoenixFintech.Transfers`:

- `quote_transfer(user_id, attrs)` builds and persists a transfer quote.
- `get_transfer_quote!(id)` loads a quote.
- `requote_transfer_quote(user_id, quote_id)` creates a new quote from the prior quote's input snapshot.
- `create_transfer_from_quote(user_id, quote_id, attrs \\ %{})` creates a transfer from an accepted quote.

The existing `create_transfer/2` can remain temporarily for compatibility, but new UI flow should move toward quote-first creation.

## Error Handling

Quote items return domain errors as atoms or tuples, such as `:missing_fx_rate`, `:unsupported_currency_pair`, or `{:missing_requirement, item, key}`. The pipeline halts on the first error and returns the item module, reason, and partial context for debugging.

## Testing

Tests should cover:

- pipeline order and successful context transformation.
- no-op item behavior when a fee or FX item does not apply.
- dependency failure when an item requires a missing fact.
- persisted `transfer_quotes` include both input and calculation snapshots.
- requoting creates a distinct immutable quote.
- transfer creation can reference the broader quote.
