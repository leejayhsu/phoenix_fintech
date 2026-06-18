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
