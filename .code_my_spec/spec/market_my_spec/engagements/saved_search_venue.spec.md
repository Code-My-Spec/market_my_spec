# MarketMySpec.Engagements.SavedSearchVenue

Join schema for the many-to-many between SavedSearch and Venue. Fields: saved_search_id (FK), venue_id (FK), account_id (FK, denormalized for fast account-scoped queries). Deleting either side cascades only the join row.

## Type

schema
