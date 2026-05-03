defmodule MarketMySpec do
  @moduledoc """
  MarketMySpec keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  use Boundary, top_level?: true, exports: {:all, except: [Repo]}
end
