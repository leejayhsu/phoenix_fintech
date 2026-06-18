---
name: admin-panels
description: Guidelines for building admin panel pages (list/index tables with CRUD actions)
---

# Admin Panels

General guidelines for building admin pages that display and manage records for a model.

## Table guidelines

- Any column that shows a unique identifier (such as an ID, slug, UUID, or other unique token) should use the click-to-copy-to-clipboard component. The value should be displayed as the copyable text, and clicking it should copy the value to the clipboard.
- When building the table, only show the most important columns. We don't want columns to be too wide, so be selective about what fields are displayed. Hide less important fields behind the detail/view page rather than cramming them into the table.
- Always make the last column an actions column that has a hamburger dropdown (`dropdown` + `dropdown-content`) with further actions like view, edit, and delete.
- When building the table we should usually have view, edit, and delete functionality for each row. These are surfaced as items in the actions dropdown menu and should each navigate to (or open) the respective view/edit page, or trigger a delete confirmation for delete.
