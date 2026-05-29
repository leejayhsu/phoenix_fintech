# Party Detail Tabs Design

## Context

The party detail page currently shows party members and compliance documents side by side on `/app/parties/:id`. That makes the page feel busy, especially now that party members render as a LiveFlow tree. The goal is to give each workflow more space while keeping every section directly bookmarkable.

## Goals

- Keep `/app/parties/:id` valid as a calm party overview page.
- Move party members to `/app/parties/:id/members`.
- Move compliance documents to `/app/parties/:id/documents`.
- Add a route-aware tab bar across all three pages.
- Preserve the existing member tree, member modal, role toggles, deletion, upload form, and document list behavior.
- Add hard-coded overview details so the overview looks intentionally fleshed out.

## Non-Goals

- Do not add new database fields for overview data.
- Do not change member or compliance document persistence.
- Do not redesign onboarding, party creation, or transfer flows.
- Do not add inline scripts or new asset bundles.

## Routes

Add two authenticated LiveView routes inside the existing authenticated `live_session`:

- `/app/parties/:id` -> `PartyShowLive`, overview tab.
- `/app/parties/:id/members` -> `PartyShowLive`, members tab.
- `/app/parties/:id/documents` -> `PartyShowLive`, documents tab.

The LiveView can distinguish tabs through route action or params. The implementation should use the route as the source of truth for the active tab so browser refresh, direct navigation, and bookmarks all restore the same section.

## Page Structure

Every tab uses the existing `<Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>` wrapper.

The shared header shows:

- Party legal name.
- Tax ID.
- Route links for Overview, Members, and Documents.

The tabs should use daisyUI classes so the implementation follows the app's installed component system. Use a compact `tabs tabs-box` or similarly quiet daisyUI tab treatment with `tab` links and `tab-active` on the active route. Customize only with Tailwind utilities when needed for spacing or layout. Do not use large marketing cards for navigation. Each tab link should have a stable DOM ID for LiveView tests:

- `party-overview-tab`
- `party-members-tab`
- `party-documents-tab`

## Overview Tab

`/app/parties/:id` renders a spacious overview with real party identity from the database and hard-coded supporting details. The dummy data is presentation-only and should stay local to the LiveView/template.

Render these sections:

- Summary cards for onboarding status, risk rating, relationship manager, and expected monthly volume.
- A business profile section with hard-coded industry, operating regions, and primary currency.
- A recent activity section with hard-coded activity entries.
- Compact calls to view party members and compliance documents using route links.

The overview should avoid showing the full member tree or upload form. It can show counts based on loaded `party.members` and `party.compliance_documents`.

## Members Tab

`/app/parties/:id/members` renders the existing party member workflow full width:

- Existing `#add-top-level-member-button`.
- Existing member modal and `#party-member-form`.
- Existing LiveFlow tree with `#party-member-flow`.
- Existing add child, delete, and role toggle events.

The LiveFlow area should have more horizontal breathing room than the current two-column layout.

## Documents Tab

`/app/parties/:id/documents` renders the existing document workflow full width:

- Existing `#party-document-form`.
- Existing `#upload-document-button`.
- Existing `#documents` stream.
- Existing upload handling through `allow_upload/3` and `consume_uploaded_entries/3`.

The upload form and document list should be visually separated, but not split beside the member tree.

## Data Flow

`mount/3` continues to load `Parties.get_party_with_details!/1`, which preloads members and compliance documents. The LiveView assigns the active tab from the route and initializes only the state required by the rendered workflows.

For simplicity, it is acceptable to keep the member form, member flow, document form, upload config, and document stream initialized in the same LiveView for all tabs. If this becomes noisy, helper functions should make the render branches clear without introducing a LiveComponent.

## Error Handling

Existing member and document errors remain unchanged:

- Member validation errors keep the modal open with form errors.
- Failed uploads flash `"Document upload failed"`.

Missing parties continue to use the current bang lookup behavior.

## Testing

Update `PartyShowLiveTest` with route-specific tests:

- Overview route renders `#party-details`, `#party-overview`, and the three tab links.
- Members route renders `#party-members-panel`, keeps the LiveFlow tree visible, and supports existing member mutation tests.
- Documents route renders `#party-documents-panel` and document upload form/list elements.
- Tab links point to `/app/parties/:id`, `/app/parties/:id/members`, and `/app/parties/:id/documents`.

Existing member behavior tests should move to the members route so they test the routed page users will actually use.
