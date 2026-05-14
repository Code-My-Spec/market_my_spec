# MarketMySpecWeb.VenueLive.Index

Account-scoped venue admin. Lists venues for the active account with source, identifier, weight, and enabled toggle. Inline form to add new venues, edit/remove actions per row, optimistic toggle for enabled flag. Per-source identifier validation surfaces inline before submit.

## Type

liveview

## Route

`/accounts/:id/venues`

## Dependencies

- MarketMySpec.Engagements

## User Interactions

- Add venue button — opens inline form with source selector, identifier input, and weight input
- Submit add form — validates identifier via Source.validate_venue/1 and persists; shows inline error on invalid identifier
- Enabled toggle — optimistically toggles venue enabled flag via update_venue
- Edit row — opens inline edit form pre-filled with existing venue values
- Delete row — removes venue with confirmation; removed from list on success

## Design

Table with columns: source badge, identifier, weight, enabled toggle, and action buttons (edit, delete). Inline form row appears above or below the table when adding. Edit mode replaces the row with an editable form. Validation errors surface inline next to the identifier field. Uses account-scoped navigation.
