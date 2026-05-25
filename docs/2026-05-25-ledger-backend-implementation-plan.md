# Ledger Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Follow TDD: write each failing test first, verify it fails for the expected reason, then implement.

**Goal:** Implement the backend-only ledger domain from `docs/app-design.md`: currencies, ledger accounts, account balances, journal entries, ledger entries, flexible journal ownership references, balancing rules, and conservative posted-balance updates.

**Architecture:** Add a `PhoenixFintech.Ledger` context with focused Ecto schemas under `lib/phoenix_fintech/ledger/`. Controllers and LiveViews must not create ledger records directly; all writes go through context APIs using `Ecto.Multi`.

**Tech Stack:** Phoenix 1.8, Ecto, PostgreSQL, `Decimal`, existing `PhoenixFintech.Repo`, binary IDs.

---

## Summary

Build the ledger backend only. Do not add frontend routes, LiveViews, controllers, or templates.

The implementation should support:

- ISO-style currency rows using `currencies.code` as primary key.
- Ledger accounts of type `:nostro`, `:user`, or `:system`.
- One balance row per `{ledger_account_id, currency_code}`.
- Journal entries with flexible ownership via `source_type` and `source_id`.
- Journal entries with optional `party_id` for party-specific accounting context.
- Two or more child ledger entries per journal entry.
- Per-currency debit/credit balancing before insert.
- Posted-balance updates inside the same transaction as journal creation.
- Rejection of journals that would make a non-negative account's posted balance go below zero.

Use `ledger_journal_entries.source_type` and `ledger_journal_entries.source_id` instead of a direct `transfer_id` column. This keeps the ledger usable for transfers, manual adjustments, fees, provider settlements, reversals, and future owner types without changing the ledger schema each time. Because this is a typed polymorphic reference, do not add a database foreign key for `source_id`.

## Public APIs

Add `PhoenixFintech.Ledger` with these functions:

```elixir
create_currency(attrs) :: {:ok, Currency.t()} | {:error, Ecto.Changeset.t()}
list_currencies() :: [Currency.t()]
get_currency!(code) :: Currency.t()

create_account(attrs) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
get_account!(id) :: Account.t()
list_accounts() :: [Account.t()]

get_or_create_account_balance(account_id, currency_code) ::
  {:ok, AccountBalance.t()} | {:error, Ecto.Changeset.t()}

create_journal_entry(attrs) ::
  {:ok, JournalEntry.t()} |
  {:error, :entries, Ecto.Changeset.t(), map()} |
  {:error, atom(), Ecto.Changeset.t(), map()}

get_journal_entry!(id) :: JournalEntry.t()
```

`create_journal_entry/1` should accept attrs shaped like:

```elixir
%{
  "source_type" => "transfer",
  "source_id" => transfer_id,
  "type" => "internal",
  "status" => "posted",
  "party_id" => nil,
  "entries" => [
    %{
      "ledger_account_id" => debit_account_id,
      "amount" => "100.00",
      "direction" => "debit",
      "currency_code" => "USD"
    },
    %{
      "ledger_account_id" => credit_account_id,
      "amount" => "100.00",
      "direction" => "credit",
      "currency_code" => "USD"
    }
  ]
}
```

For v1, valid `source_type` values should be:

```elixir
[:transfer, :manual_adjustment, :fee, :provider_settlement, :reversal]
```

For v1, only `status: :posted` should update balances. Other lifecycle statuses are deferred until transfer lifecycle behavior is designed.

## Schema And Migration Plan

Generate the migration with:

```bash
mix ecto.gen.migration create_ledger_tables
```

Create:

- `currencies`
  - `code :string, primary_key: true`
  - `name :string, null: false`
  - `minor_unit :integer, null: false`
  - check `char_length(code) = 3`
  - check `minor_unit >= 0 and minor_unit <= 6`

- `ledger_accounts`
  - binary `id`
  - `type :string, null: false`
  - `name :string, null: false`
  - `is_negative_balance_allowed :boolean, null: false, default: false`

- `ledger_account_balances`
  - binary `id`
  - `ledger_account_id` FK to `ledger_accounts`
  - `currency_code` FK to `currencies.code`, type `:string`
  - `pending_balance :decimal, null: false, default: 0`
  - `available_balance :decimal, null: false, default: 0`
  - `posted_balance :decimal, null: false, default: 0`
  - unique index on `[:ledger_account_id, :currency_code]`

- `ledger_journal_entries`
  - binary `id`
  - nullable `source_type :string`
  - nullable `source_id :binary_id`
  - nullable `party_id` FK to `parties`
  - `status :string, null: false`
  - `type :string, null: false`
  - index on `[:source_type, :source_id]`
  - index on `[:party_id]`
  - check constraint requiring `source_type` and `source_id` to be both present or both null

- `ledger_entries`
  - binary `id`
  - `ledger_journal_entry_id` FK to `ledger_journal_entries`
  - `ledger_account_id` FK to `ledger_accounts`
  - `amount :decimal, null: false`
  - `direction :string, null: false`
  - `currency_code` FK to `currencies.code`, type `:string`
  - check `amount > 0`
  - indexes on journal, account, and currency

## Implementation Tasks

### Task 1: Write failing ledger context tests

**Files:**

- Create: `test/phoenix_fintech/ledger_test.exs`

- [ ] **Step 1: Create the ledger test module**

Create `test/phoenix_fintech/ledger_test.exs` with tests covering:

- `create_currency/1` uppercases currency codes and rejects non-3-character codes.
- `create_account/1` creates a valid account and rejects invalid account types.
- `get_or_create_account_balance/2` creates one zeroed balance row and returns the existing row on repeated calls.
- `create_journal_entry/1` accepts paired `source_type` and `source_id`.
- `create_journal_entry/1` rejects `source_type` without `source_id`, and `source_id` without `source_type`.
- `create_journal_entry/1` rejects journals with fewer than two entries.
- `create_journal_entry/1` rejects same-currency journals where debit total does not equal credit total.
- `create_journal_entry/1` rejects multi-currency journals unless each currency balances independently.
- `create_journal_entry/1` inserts a balanced posted journal and preloads entries.
- Posted journals update `posted_balance`: debits increase the account balance, credits decrease it.
- Posted journals reject credits that would make a non-negative account balance negative.
- Posted journals allow negative balances when `is_negative_balance_allowed` is true.

- [ ] **Step 2: Run the failing tests**

Run:

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: compile failure or undefined module/function errors for `PhoenixFintech.Ledger`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add test/phoenix_fintech/ledger_test.exs
git commit -m "test: add ledger backend expectations"
```

### Task 2: Add ledger schemas and migration

**Files:**

- Create: `priv/repo/migrations/*_create_ledger_tables.exs`
- Create: `lib/phoenix_fintech/ledger/currency.ex`
- Create: `lib/phoenix_fintech/ledger/account.ex`
- Create: `lib/phoenix_fintech/ledger/account_balance.ex`
- Create: `lib/phoenix_fintech/ledger/journal_entry.ex`
- Create: `lib/phoenix_fintech/ledger/entry.ex`

- [ ] **Step 1: Generate the migration**

Run:

```bash
mix ecto.gen.migration create_ledger_tables
```

- [ ] **Step 2: Implement the migration**

Create the tables and indexes described in "Schema And Migration Plan". Use `:binary_id` primary keys for all ledger tables except `currencies`, where `code` is the string primary key. Keep `source_id` without a foreign key.

- [ ] **Step 3: Add schema modules**

Use existing project conventions:

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
timestamps(type: :utc_datetime)
```

Use this exception for `Currency`:

```elixir
@primary_key {:code, :string, autogenerate: false}
```

Use these enum values:

```elixir
Account.type: [:nostro, :user, :system]
JournalEntry.source_type: [:transfer, :manual_adjustment, :fee, :provider_settlement, :reversal]
JournalEntry.type: [:deposit, :disbursement, :internal_fx, :internal]
JournalEntry.status: [:posted]
Entry.direction: [:debit, :credit]
```

Normalize all currency codes with `String.upcase/1` in changesets. Validate currency code length with `validate_length(:currency_code, is: 3)` or `validate_length(:code, is: 3)`. Validate entry amounts with `validate_number(:amount, greater_than: 0)`.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: tests still fail because `PhoenixFintech.Ledger` APIs are missing.

- [ ] **Step 5: Commit schemas and migration**

```bash
git add priv/repo/migrations lib/phoenix_fintech/ledger
git commit -m "feat: add ledger schemas and tables"
```

### Task 3: Implement simple Ledger APIs

**Files:**

- Create: `lib/phoenix_fintech/ledger.ex`

- [ ] **Step 1: Implement currency helpers**

Implement:

```elixir
def create_currency(attrs), do: %Currency{} |> Currency.changeset(attrs) |> Repo.insert()
def list_currencies, do: Repo.all(from c in Currency, order_by: [asc: c.code])
def get_currency!(code), do: Repo.get!(Currency, String.upcase(code))
```

- [ ] **Step 2: Implement account helpers**

Implement:

```elixir
def create_account(attrs), do: %Account{} |> Account.changeset(attrs) |> Repo.insert()
def list_accounts, do: Repo.all(from a in Account, order_by: [asc: a.name])
def get_account!(id), do: Repo.get!(Account, id)
```

- [ ] **Step 3: Implement balance helper**

Implement `get_or_create_account_balance/2` so it:

- uppercases the currency code
- returns an existing `{ledger_account_id, currency_code}` row when present
- otherwise inserts a zeroed balance
- uses `unique_constraint([:ledger_account_id, :currency_code])` in the changeset for race safety

- [ ] **Step 4: Run focused tests**

Run:

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: currency/account/balance tests pass; journal tests still fail.

- [ ] **Step 5: Commit simple APIs**

```bash
git add lib/phoenix_fintech/ledger.ex lib/phoenix_fintech/ledger/account_balance.ex
git commit -m "feat: add ledger account and currency APIs"
```

### Task 4: Implement journal validation helpers

**Files:**

- Modify: `lib/phoenix_fintech/ledger.ex`
- Modify as needed: `lib/phoenix_fintech/ledger/journal_entry.ex`
- Modify as needed: `lib/phoenix_fintech/ledger/entry.ex`

- [ ] **Step 1: Validate polymorphic source pairing**

Require `source_type` and `source_id` to be both present or both absent. Return an invalid journal-entry changeset when only one is supplied.

- [ ] **Step 2: Validate entries shape**

Require `entries` to be a list with at least two maps. Reject shorter lists before inserting anything.

- [ ] **Step 3: Validate per-currency balance**

Normalize each entry currency to uppercase, group entries by currency, sum debit and credit totals per currency with `Decimal.add/2`, and reject if any currency's debit total differs from its credit total.

For pre-insert entry validation failures, return:

```elixir
{:error, :entries, changeset, %{}}
```

Tests should assert messages like:

```elixir
assert %{entries: ["must include at least two entries"]} = errors_on(changeset)
assert %{entries: ["must balance debits and credits per currency"]} = errors_on(changeset)
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: validation tests pass; insert/balance-update tests may still fail.

- [ ] **Step 5: Commit journal validation**

```bash
git add lib/phoenix_fintech/ledger.ex lib/phoenix_fintech/ledger/journal_entry.ex lib/phoenix_fintech/ledger/entry.ex test/phoenix_fintech/ledger_test.exs
git commit -m "feat: validate ledger journal entries"
```

### Task 5: Implement transactional journal creation

**Files:**

- Modify: `lib/phoenix_fintech/ledger.ex`

- [ ] **Step 1: Insert journal and entries with `Ecto.Multi`**

`create_journal_entry/1` must:

- validate source pairing, entry count, and per-currency balance before inserting rows
- insert `ledger_journal_entries`
- insert each `ledger_entries` row with the inserted journal ID
- return the inserted journal preloaded with `:entries`

- [ ] **Step 2: Update balances inside the same transaction**

For each affected `{ledger_account_id, currency_code}`:

- ensure an account balance row exists
- lock the balance row with a query using `lock: "FOR UPDATE"`
- update `posted_balance` only for posted journals
- leave `pending_balance` and `available_balance` unchanged

Use this v1 balance rule:

```elixir
direction == :debit  -> posted_balance + amount
direction == :credit -> posted_balance - amount
```

- [ ] **Step 3: Enforce non-negative balances**

Before updating a locked balance row, load the associated account. If the resulting `posted_balance` is less than zero and `is_negative_balance_allowed` is false, return an invalid balance changeset from the multi step and roll back the whole transaction.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: all ledger tests pass.

- [ ] **Step 5: Commit transactional journal creation**

```bash
git add lib/phoenix_fintech/ledger.ex test/phoenix_fintech/ledger_test.exs
git commit -m "feat: create balanced ledger journals"
```

### Task 6: Run final verification

**Files:**

- Modify only if verification reveals issues.

- [ ] **Step 1: Run focused tests**

```bash
mix test test/phoenix_fintech/ledger_test.exs
```

Expected: pass.

- [ ] **Step 2: Run all tests**

```bash
mix test
```

Expected: pass.

- [ ] **Step 3: Run project precommit**

```bash
mix precommit
```

Expected: pass. If `mix precommit` formats files, inspect the diff and rerun `mix precommit`.

- [ ] **Step 4: Commit verification fixes if needed**

If verification required changes:

```bash
git add .
git commit -m "fix: resolve ledger verification issues"
```

## Acceptance Criteria

The work is complete when:

- `PhoenixFintech.Ledger` exists and is the only write interface for ledger records.
- All ledger tables and indexes exist through a generated migration.
- `ledger_journal_entries` uses `source_type` and `source_id`, not `transfer_id`.
- Source type and source ID are either both present or both absent.
- Journal creation is atomic: journal, entries, and balance changes commit or roll back together.
- Unbalanced journals are rejected before inserting entries.
- Multi-currency journals must balance independently per currency.
- Non-negative accounts cannot be credited below zero.
- No frontend route, LiveView, controller, or template is added.
- `mix precommit` passes.

## Assumptions

- Backend only; no `/app/ledger/*` UI work in this pass.
- Ledger journal ownership uses typed polymorphic references: `source_type` plus `source_id`.
- `source_id` intentionally has no database foreign key because it can reference multiple future owner tables.
- `party_id` remains a normal nullable foreign key because it describes party-specific accounting context, not ownership.
- Only posted journals change balances in v1.
- Debits increase `posted_balance`; credits decrease `posted_balance`.
- Pending and available balance transitions are deferred until transfer lifecycle states are implemented.
- Currency codes are stored uppercase and must be exactly three characters.
