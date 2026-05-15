defmodule MarketMySpec.McpServers.Engagements.Tools.DeleteSearch do
  @moduledoc """
  MCP tool that deletes a SavedSearch scoped to the calling account.

  Returns the removed search summary on success, or an error response when
  the search does not exist or belongs to a different account. Cascade only
  touches the join rows; linked venues stay.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :search_id, :integer, required: true, doc: "SavedSearch id to delete"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    search_id = Map.fetch!(params, :search_id)

    case Engagements.delete_saved_search(scope, search_id) do
      {:ok, search} ->
        payload = %{search: %{id: search.id, name: search.name}}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Saved search not found: #{search_id}"), frame}
    end
  end
end
