# Party Members Tree Design

## Goal

Update the party details page so party members are shown as a parent-child tree instead of a flat list. Member creation should happen in a modal, with entry points for both top-level members and child members.

## Scope

- Replace the inline party member creation form with a modal.
- Add an "Add top-level member" action above the tree.
- Add a compact add-child action on each member row.
- Render members nested under their `parent_party_member_id`.
- Keep role toggles and delete actions available on each member.
- Keep the existing parent selector in the modal so users can adjust placement before submitting.

## Architecture

The change stays inside `PhoenixFintechWeb.PartyShowLive`. The existing `party_members.parent_party_member_id` relationship is sufficient, so no schema or migration changes are needed.

The LiveView will maintain a regular member list assign for tree rendering and continue using stream operations only where they still fit existing behavior. A helper will group members by parent ID and recursively render nested rows from top-level members down through descendants.

## Interaction

- Clicking "Add top-level member" opens the modal with no parent selected.
- Clicking a member's add-child button opens the same modal with that member selected as the parent.
- Submitting the modal creates the member, closes the modal, resets the form, and refreshes the tree.
- Validation errors keep the modal open and display errors in the form.
- Deleting or toggling a member updates the rendered tree and parent options.

## Testing

LiveView tests should cover:

- The party details page renders the member tree container.
- The top-level add button opens the modal with no parent selected.
- A member add-child button opens the modal with that member selected as parent.
- A created child member renders under its parent in the tree.
