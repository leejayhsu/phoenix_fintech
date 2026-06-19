---
name: domain-rules
description: Core business logic guidelines for the fintech domain (transactions, accounts, balances, transfers). Use when implementing or modifying domain rules, validations, or workflows. Does NOT cover infrastructure, code style, or framework conventions.
---

# Domain Rules

This skill captures the **core business logic** of the application — the domain rules that define how the product behaves, regardless of how they are implemented in code or infrastructure.

Use this skill when:
- Implementing or modifying domain logic (transactions, transfers, payments, balances, fees, limits)
- Adding or changing business validations and invariants
- Working through workflows that involve money movement or account state transitions
- Reasoning about edge cases in financial calculations, rounding, or authorization

Do NOT use this skill for:
- Code style, formatting, or framework conventions (see AGENTS.md and other skills)
- Infrastructure, deployment, or tooling concerns
- UI/UX or presentation layer guidelines

## State machines

- Any state machine transition on an entity **must** be recorded as a row in the corresponding `entity_events` table. State changes are never silent at the data layer — there is always an audit trail.
- As a general rule, a state change should result in a notification to the user who owns the entity. This is not a hard guarantee: some state changes may not warrant a notification, and some sensitive details may need to be hidden from (or withheld entirely from) the user. If you are unsure whether a given state change should notify the user, **ask the user** rather than assuming.

## Transfers
- The transfer model should have a direction; it should be a send or a receive. In a receive the counterparty is sending money to the originator and in a send the originator is sending money to the counterparty.
- This creates a dichotomy where, depending on the direction, the originator is either the sender or the recipient of the money
- deposit is incoming money to our system. disbursements are outgoing money. for a send, the originator deposits to us, and we disburse to the counterparty. for a receive, the counterparty deposits to us, and we disburse to the originator.

## Notifications
- Notifications should generally be sent after any state change of a state-machine-governed model. There are exceptions to this rule, for instance if it's purely an internal process that the user never needs to know about, but this is probably rare. Since this is not a production app, you can safely default to notifying on most things.
- Notifications should be best effort and should never be atomic with the underlying database changes or, in other words, a failed notification should not fail the rest of the database transaction 

<!-- Add concrete business rules below as they are defined. Examples:

## Transfers
- A transfer debits the source account and credits the destination account atomically.
- Transfers between accounts of the same user are fee-free; cross-user transfers incur a 1.5% fee.
- The minimum transfer amount is $0.01; the maximum per transfer is $10,000.00.
- Transfers that would leave the source account below $0.00 are rejected.

## Balances
- Account balances are stored as integers in cents to avoid floating point errors.
- All displayed amounts are localized to the user's locale using US localization for now.

## Authorization
- A user may only access accounts they own or are explicitly granted access to.
- Admin actions require an admin-scoped session.
-->

## Parties & originator eligibility

Every party can act as a **counterparty** by default. Acting as an **originator** (the party that initiates a transfer through our system) requires a separate, enhanced compliance check on top of the standard onboarding review.

### `can_originate`
- The `parties.can_originate` column (boolean, default `false`, never user-editable) gates whether a party may originate transfers.
- It is flipped to `true` **only** as the side effect of an approved `originator_status` compliance review (see below). It is never set directly from user input — it is applied programmatically via `Ecto.Changeset.change/2`, not through the party's cast changeset.

### Compliance reviews: `purpose`
- `compliance_reviews.purpose` distinguishes the two kinds of review a party can undergo:
  - `"onboarding"` — the initial KYC/onboarding review created at party creation. Drives the party **state machine** (advances party to `compliance_approved` / `compliance_rejected` / `compliance_manual_review` and records a `PartyEvent`).
  - `"originator_status"` — the enhanced review requested later to gain originator eligibility.
- A party may have at most one review per purpose (enforced by a composite unique index on `(party_id, purpose)` where `party_id IS NOT NULL`).

### Originator status workflow
- A party may **request originator status** only when:
  1. its onboarding (`"onboarding"`) compliance review is `approved`, and
  2. it is not already originator eligible (`can_originate` is `false`), and
  3. there is no in-progress (`created` or `manual_review`) `"originator_status"` review for the party.
- Requesting creates a new `compliance_reviews` row with `purpose: "originator_status"`, `status: "created"`. This surfaces in the existing admin compliance review workflow; only admins approve/reject it.
- **Originator status is NOT modeled in the party state machine.** Approving an `"originator_status"` review does **not** transition the party's `status` (the party stays at whatever onboarding state it reached, typically `compliance_approved`).
- Instead, on approval two things happen atomically in one transaction:
  1. `parties.can_originate` is set to `true`, and
  2. a `PartyEvent` with `event_type: "originator_status_granted"` (and `from_status`/`to_status` left `nil`, since it is not a state-machine transition) is inserted to preserve the audit trail.
- Rejecting an `"originator_status"` review leaves `can_originate` unchanged and emits no party event.
- Because the grant is recorded as a `PartyEvent` (not a state transition), it is auditable through the same party event log without polluting the party lifecycle states.
