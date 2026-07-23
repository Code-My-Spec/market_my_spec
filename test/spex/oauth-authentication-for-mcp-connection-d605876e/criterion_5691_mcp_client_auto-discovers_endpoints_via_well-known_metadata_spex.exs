defmodule MarketMySpecSpex.Story612.Criterion5691Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5691 — MCP client auto-discovers endpoints via well-known metadata
  """

  use MarketMySpecSpex.Case

  spex "OAuth well-known metadata discovery" do
    scenario "MCP client fetches the well-known metadata document" do
      given_ "an MCP client about to connect", context do
        {:ok, context}
      end

      when_ "it requests the OAuth authorization server metadata", context do
        conn = get(context.conn, "/.well-known/oauth-authorization-server")
        metadata = json_response(conn, 200)
        {:ok, Map.merge(context, %{conn: conn, metadata: metadata})}
      end

      then_ "the response is a JSON document", context do
        assert is_map(context.metadata)
        {:ok, context}
      end

      then_ "the document contains an authorization_endpoint", context do
        assert Map.has_key?(context.metadata, "authorization_endpoint")
        {:ok, context}
      end

      then_ "the document contains a token_endpoint", context do
        assert Map.has_key?(context.metadata, "token_endpoint")
        {:ok, context}
      end

      then_ "the document contains a registration_endpoint for dynamic client registration", context do
        assert Map.has_key?(context.metadata, "registration_endpoint")
        {:ok, context}
      end
    end
  end
end
