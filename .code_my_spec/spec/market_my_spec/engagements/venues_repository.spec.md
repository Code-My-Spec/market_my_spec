# MarketMySpec.Engagements.VenuesRepository

Account-scoped CRUD for venues. list_venues/2 (account, optional source filter), get_venue/2, create_venue/2, update_venue/3, delete_venue/2. Validates the venue identifier against Source.validate_venue/1 before persisting and rejects cross-account access with not-found.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Venue
- MarketMySpec.Engagements.Source

## Functions

- list_venues/2 — returns all venues for an account with optional source filter
- get_venue/2 — fetches a single venue by id scoped to an account; returns not-found on cross-account access
- create_venue/2 — validates identifier via Source.validate_venue/1 then persists a new Venue
- update_venue/3 — validates identifier then updates an existing Venue scoped to account
- delete_venue/2 — deletes a Venue scoped to account
