# Phoenix Fintech App Design

This is a cross-border payments application. Users create FX money movements on
behalf of other businesses, so the product model is B2B2B.

The Phoenix application should model the domain in Ecto contexts first, then
expose workflows through authenticated Phoenix controllers or LiveViews under
`/app`. Keep business invariants in context functions and changesets; templates
and controllers should orchestrate those APIs rather than encode financial
rules.

## Abbreviations

- LJE: ledger journal entry
- UBO: ultimate beneficial owner
- FX: foreign exchange

## Existing Application Baseline

- OTP app: `:phoenix_fintech`
- Web namespace: `PhoenixFintechWeb`
- Domain namespace: `PhoenixFintech`
- Database access: `PhoenixFintech.Repo`
- Current auth context: `PhoenixFintech.Accounts`
- User schema: `PhoenixFintech.Accounts.User`
- Primary keys and foreign keys currently use `:binary_id`

New fintech domain work should follow the same project shape:

- Put Ecto schemas in focused context namespaces under `lib/phoenix_fintech/`.
- Put public business APIs in context modules such as `PhoenixFintech.Transfers`,
  `PhoenixFintech.Ledger`, and `PhoenixFintech.Parties`.
- Generate migrations with `mix ecto.gen.migration migration_name`.
- Use `Decimal` values for money fields. Never use floats for currency amounts.
- Store currencies with ISO 4217 three-letter codes such as `USD`, `MXN`, and
  `EUR`.

## Suggested Context Boundaries

### `PhoenixFintech.Transfers`

Owns the core money movement workflow.

- Creates and updates transfers.
- Validates transfer direction, currencies, and amounts.
- Coordinates with `PhoenixFintech.Parties` for originator and counterparty
  references.
- Calls `PhoenixFintech.Ledger` to create zero-sum ledger journal entries when a
  transfer changes financial state.

### `PhoenixFintech.Ledger`

Owns accounting primitives and balance integrity.

- Creates ledger accounts and account balances.
- Creates ledger journal entries and their child ledger entries.
- Enforces that each journal entry is balanced per currency before insert.
- Handles pending, available, and posted balance transitions.

Ledger invariants should be enforced inside context functions using
`Ecto.Multi` transactions. Do not let controllers or LiveViews insert ledger
entries directly.

### `PhoenixFintech.Parties`

Owns business participants and their ownership or representative structures.

- Creates parties for businesses participating in transfers.
- Stores party members, including UBOs and legal representatives.
- Provides APIs to load a full member tree for a party.
- Stores government IDs through a controlled API that can redact values in logs
  and inspect output.

## Core Entities

### Transfers

Transfers are the core primitive of the fintech app. The first supported
transfer type is remittance, meaning a cross-border transfer between an
originator and a counterparty.

The originator is the party that initiates the transfer. The originator can be
either the sender or the recipient, depending on product flow. The counterparty
is the other side of the transfer.

Transfers have a one-to-many relationship with ledger journal entries.

Transfer fields:

- `id`
- `created_by_user_id`
- `originator_party_id`
- `counterparty_party_id`
- `direction`: `payout` or `payin`
- `start_currency_code`
- `end_currency_code`
- `start_amount`
- `end_amount`
- `status`
- timestamps

### Ledger Journal Entries

Ledger journal entries group ledger entries into balanced accounting events.
The sum of credits must equal the sum of debits for each currency represented in
the journal entry.

Ledger journal entries may reference a transfer and may also reference parties
when the accounting event is party-specific.

Journal entry fields:

- `id`
- `transfer_id`
- `party_id`
- `status`
- `type`: `deposit`, `disbursement`, `internal_fx`, or `internal`
- timestamps

### Ledger Entries

Ledger entries are the individual debit or credit rows inside a ledger journal
entry. They belong to a ledger journal entry and a ledger account.

Ledger entry fields:

- `id`
- `ledger_journal_entry_id`
- `ledger_account_id`
- `amount`
- `direction`: `debit` or `credit`
- `currency_code`
- timestamps

### Ledger Accounts

Ledger accounts represent nostro, user, and system accounts. They are separate
from external bank accounts and should be used for internal bookkeeping.

Ledger account fields:

- `id`
- `type`: `nostro`, `user`, or `system`
- `name`
- `is_negative_balance_allowed`
- timestamps

### Ledger Account Balances

Ledger account balances track each account and currency pair.

Balance fields:

- `ledger_account_id`
- `currency_code`
- `pending_balance`
- `available_balance`
- `posted_balance`
- timestamps

Use a composite unique index on `ledger_account_id` and `currency_code`.

### Currencies

Currencies should use ISO 4217 three-letter codes as primary keys.

Currency fields:

- `code`
- `name`
- `minor_unit`
- timestamps

### Parties

Parties are business participants in transfers.

Party fields:

- `id`
- `tax_id`
- `legal_name`
- `address_line1`
- `address_line2`
- `locality`
- `region`
- `postal_code`
- `country_code`
- timestamps

Addresses can start as columns for speed of implementation. If address reuse,
history, or validation becomes complex, split them into an address table later.

### Party Members

Party members are businesses or individuals associated with a party. They can be
UBOs, legal representatives, or nested business owners.

Use an adjacency-list tree initially:

- `party_id` links every member to the root party.
- `parent_party_member_id` links a child member to its parent member.
- A `nil` parent means the member is directly attached to the party.

This keeps writes simple and supports recursive CTE queries for loading the full
tree. If reads become hot or tree depth becomes large, add a closure table later.

Party member fields:

- `id`
- `party_id`
- `parent_party_member_id`
- `legal_name`
- `type`: `business` or `individual`
- `title`
- `is_legal_rep`
- `is_ubo`
- `address_line1`
- `address_line2`
- `locality`
- `region`
- `postal_code`
- `country_code`
- timestamps

### Government IDs

Government IDs should be stored through a polymorphic ownership pattern that is
explicit enough for Ecto and database constraints.

Prefer separate nullable foreign keys plus a check constraint over a generic
`owner_type` and `owner_id` pair:

- `party_id`
- `party_member_id`
- future owner foreign keys as needed

Add a database check constraint that exactly one owner foreign key is present.

Government ID fields:

- `id`
- `party_id`
- `party_member_id`
- `type`: examples include `ein`, `ssn`, `passport`, `national_id`
- `country_code`
- `value`
- timestamps

The schema should mark sensitive fields with `redact: true`, and context APIs
should avoid returning raw values unless the caller explicitly needs them.

## Ecto Schema Notes

- Use `@primary_key {:id, :binary_id, autogenerate: true}` and
  `@foreign_key_type :binary_id` to match the current `User` schema.
- Use `field :amount, :decimal` for all money amounts.
- Use `Ecto.Enum` for controlled statuses and types when values are internal to
  the app.
- Add database constraints for uniqueness, foreign keys, balance checks, and
  allowed positive amount values.
- Fields set by the system, such as `created_by_user_id`, must not be included
  in public `cast/4` calls. Set them explicitly in context functions.

## Initial Database Tables

### `transfers`

- `id`
- `created_by_user_id`
- `originator_party_id`
- `counterparty_party_id`
- `direction`
- `start_currency_code`
- `end_currency_code`
- `start_amount`
- `end_amount`
- `status`
- timestamps

### `ledger_journal_entries`

- `id`
- `transfer_id`
- `party_id`
- `status`
- `type`
- timestamps

### `ledger_entries`

- `id`
- `ledger_journal_entry_id`
- `ledger_account_id`
- `amount`
- `direction`
- `currency_code`
- timestamps

### `ledger_accounts`

- `id`
- `type`
- `name`
- `is_negative_balance_allowed`
- timestamps

### `ledger_account_balances`

- `ledger_account_id`
- `currency_code`
- `pending_balance`
- `available_balance`
- `posted_balance`
- timestamps

### `currencies`

- `code`
- `name`
- `minor_unit`
- timestamps

### `parties`

- `id`
- `tax_id`
- `legal_name`
- address fields
- timestamps

### `party_members`

- `id`
- `party_id`
- `parent_party_member_id`
- `legal_name`
- `type`
- `title`
- `is_legal_rep`
- `is_ubo`
- address fields
- timestamps

### `government_ids`

- `id`
- `party_id`
- `party_member_id`
- `type`
- `country_code`
- `value`
- timestamps

## Phoenix Web Surface

Start with authenticated browser workflows under the existing `/app` area.

Suggested routes:

- `/app/transfers`
- `/app/transfers/new`
- `/app/transfers/:id`
- `/app/parties`
- `/app/parties/new`
- `/app/parties/:id`
- `/app/ledger/accounts`
- `/app/ledger/journal-entries/:id`

Use LiveView when the workflow benefits from dynamic validation or step-by-step
entry, especially transfer creation and party member tree editing. Begin each
LiveView template with `<Layouts.app flash={@flash} current_scope={...}>` if
the app adopts Phoenix 1.8 scopes, and keep authenticated routes inside the
proper live session.

For controller-backed forms, use `Phoenix.Component.to_form/2` and the imported
`.input` component in HEEx templates. Give key forms and buttons stable DOM IDs
for tests.

## External HTTP Integrations

Use `Req` for all HTTP integrations. Do not introduce HTTPoison, Tesla, or
`:httpc`.

Likely future integrations:

- FX quote providers
- KYC/KYB providers
- sanctions screening
- banking or payment rails

Wrap external clients in small modules under a context namespace, then call
them from context functions or supervised workers. Keep provider response shapes
out of core Ecto schemas.

## Testing Strategy

- Use context tests for financial invariants, especially ledger balancing.
- Use `Ecto.Multi` tests to verify transfer creation and ledger creation commit
  or roll back together.
- Use controller or LiveView tests for browser workflows.
- Prefer selectors against stable DOM IDs instead of raw HTML or fragile text.
- Use `start_supervised!/1` for processes in tests.
- Avoid `Process.sleep/1`; use monitors or `:sys.get_state/1` when
  synchronization is needed.

High-priority test cases:

- A transfer cannot be created with invalid currencies or non-positive amounts.
- A ledger journal entry cannot be committed unless debit and credit totals
  balance per currency.
- Creating a transfer records `created_by_user_id` from the authenticated user,
  not from user-submitted params.
- A party member tree can be loaded for a party in parent-child order.
- A government ID belongs to exactly one supported owner type.

## Implementation Order

1. Add currencies and parties.
2. Add party members and government IDs.
3. Add ledger accounts, balances, journal entries, and ledger entries.
4. Add transfers.
5. Add context APIs that compose transfers with ledger journal entries.
6. Add authenticated `/app` UI workflows.
7. Add external provider integrations through `Req` only when a real provider is
   selected.
