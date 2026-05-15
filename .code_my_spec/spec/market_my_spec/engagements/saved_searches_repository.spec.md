# MarketMySpec.Engagements.SavedSearchesRepository

Account-scoped CRUD for SavedSearch records. Functions: list_saved_searches/1, get_saved_search/2, create_saved_search/2 (validates venue_ids belong to scope's account and the source_wildcards atom set is recognized), update_saved_search/3, delete_saved_search/2, run_saved_search/2 (resolves the recipe to a concrete venue list — specific venues plus wildcard-expanded enabled venues per source — then delegates to Engagements.Search.search/3). Cross-account access returns :not_found.

## Type

module
