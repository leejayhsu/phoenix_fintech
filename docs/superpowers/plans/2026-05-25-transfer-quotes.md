# Transfer Quotes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace FX-only transfer quotes with a broader `transfer_quotes` model and an idiomatic Elixir quote pipeline.

**Architecture:** Add a `PhoenixFintech.Transfers.Quotes` namespace with a pure `%QuoteContext{}` transformation pipeline. Persist immutable quote input and calculation snapshots in `transfer_quotes`, and make transfers reference accepted transfer quotes.

**Tech Stack:** Phoenix 1.8, Ecto, PostgreSQL, `Decimal`, `Enum.reduce_while/3`, ExUnit.

---

## File Structure

- Create `test/phoenix_fintech/transfers/quotes/pipeline_test.exs` for quote context and pipeline behavior.
- Create `test/phoenix_fintech/transfers_quote_test.exs` for persisted quote and transfer integration behavior.
- Create migration `priv/repo/migrations/*_replace_fx_quotes_with_transfer_quotes.exs`.
- Create `lib/phoenix_fintech/transfers/transfer_quote.ex` for the quote schema.
- Create `lib/phoenix_fintech/transfers/quotes/quote_context.ex` for quote state helpers.
- Create `lib/phoenix_fintech/transfers/quotes/quote_item.ex` for the callback contract.
- Create `lib/phoenix_fintech/transfers/quotes/pipeline.ex` for ordered execution.
- Create quote item modules under `lib/phoenix_fintech/transfers/quotes/items/`.
- Modify `lib/phoenix_fintech/transfers.ex` to add quote APIs and use `TransferQuote`.
- Modify `lib/phoenix_fintech/transfers/transfer.ex` to replace `fx_quote` with `transfer_quote`.
- Modify transfer LiveViews/tests enough to compile against the broader quote table.

## Task 1: Pipeline Contract

**Files:**

- Create: `test/phoenix_fintech/transfers/quotes/pipeline_test.exs`
- Create: `lib/phoenix_fintech/transfers/quotes/quote_context.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/quote_item.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/pipeline.ex`

- [ ] **Step 1: Write failing pipeline tests**

Add tests that define local quote item modules and assert ordered context transformation, no-op behavior, and missing requirement failure.

- [ ] **Step 2: Run the failing pipeline tests**

Run: `mix test test/phoenix_fintech/transfers/quotes/pipeline_test.exs`

Expected: compile failure because quote pipeline modules do not exist.

- [ ] **Step 3: Implement quote context, item behaviour, and pipeline**

Add `%QuoteContext{}` with `input`, `entities`, `facts`, `lines`, `totals`, `metadata`, and helper functions for facts and lines. Add `QuoteItem` behaviour with `apply/1` and optional `requires/0`. Add pipeline runner using `Enum.reduce_while/3`.

- [ ] **Step 4: Run pipeline tests**

Run: `mix test test/phoenix_fintech/transfers/quotes/pipeline_test.exs`

Expected: tests pass.

## Task 2: Transfer Quote Persistence

**Files:**

- Create: `test/phoenix_fintech/transfers_quote_test.exs`
- Create: `priv/repo/migrations/*_replace_fx_quotes_with_transfer_quotes.exs`
- Create: `lib/phoenix_fintech/transfers/transfer_quote.ex`
- Modify: `lib/phoenix_fintech/transfers/transfer.ex`
- Modify: `lib/phoenix_fintech/transfers.ex`

- [ ] **Step 1: Write failing persistence tests**

Add tests for `quote_transfer/2`, snapshot persistence, `requote_transfer_quote/2`, and `create_transfer_from_quote/3`.

- [ ] **Step 2: Run failing persistence tests**

Run: `mix test test/phoenix_fintech/transfers_quote_test.exs`

Expected: undefined functions/schema failures.

- [ ] **Step 3: Generate migration**

Run: `mix ecto.gen.migration replace_fx_quotes_with_transfer_quotes`

- [ ] **Step 4: Implement migration and schema**

Drop the old transfer quote foreign key/table, create `transfer_quotes`, and add `transfer_quote_id` to `transfers`.

- [ ] **Step 5: Implement quote APIs**

Implement `quote_transfer/2`, `get_transfer_quote!/1`, `requote_transfer_quote/2`, and `create_transfer_from_quote/3`.

- [ ] **Step 6: Run persistence tests**

Run: `mix test test/phoenix_fintech/transfers_quote_test.exs`

Expected: tests pass.

## Task 3: Quote Items And Existing UI Compatibility

**Files:**

- Create: `lib/phoenix_fintech/transfers/quotes/items/fx_rate.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/items/transaction_fee.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/items/fx_fee.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/items/discount.ex`
- Create: `lib/phoenix_fintech/transfers/quotes/items/platform_fee.ex`
- Modify: `lib/phoenix_fintech_web/live/transfer_new_live.ex`
- Modify: `lib/phoenix_fintech_web/live/transfer_show_live.ex`
- Modify: `test/phoenix_fintech_web/live/transfer_show_live_test.exs`

- [ ] **Step 1: Write failing item/integration tests**

Extend quote tests to assert default item lines include FX rate, transaction fee, FX fee, discount, and platform fee with deterministic v1 values.

- [ ] **Step 2: Run failing integration tests**

Run: `mix test test/phoenix_fintech/transfers_quote_test.exs test/phoenix_fintech_web/live/transfer_show_live_test.exs`

Expected: failures for missing item modules or old `fx_quote` UI references.

- [ ] **Step 3: Implement item modules and update LiveViews**

Add deterministic code-only item modules. Update transfer creation and show pages to use `transfer_quote` snapshots instead of `fx_quote`.

- [ ] **Step 4: Run integration tests**

Run: `mix test test/phoenix_fintech/transfers_quote_test.exs test/phoenix_fintech_web/live/transfer_show_live_test.exs`

Expected: tests pass.

## Task 4: Final Verification

**Files:**

- Modify any files flagged by formatter, compiler, or precommit.

- [ ] **Step 1: Run project precommit**

Run: `mix precommit`

Expected: formatter, compiler, and tests pass.

- [ ] **Step 2: Fix any issues and rerun**

Repeat `mix precommit` until it passes.
