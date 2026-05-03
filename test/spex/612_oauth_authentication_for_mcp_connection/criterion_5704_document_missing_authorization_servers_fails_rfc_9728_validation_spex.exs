defmodule MarketMySpecSpex.Story612.Criterion5704Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5704 — Document missing authorization_servers fails RFC 9728 validation

  Quality gate: the deployed protected-resource metadata document must contain
  an authorization_servers array and a resource field. If either is absent,
  MCP clients cannot discover the authorization server and this spec fails.
  """

  use MarketMySpecSpex.Case

  spex "OAuth protected resource metadata completeness" do
    scenario "the well-known protected resource document contains required RFC 9728 fields", context do
      given_ "the OAuth protected resource metadata endpoint", context do
        {:ok, context}
      end

      when_ "the metadata document is requested", context do
        conn = get(context.conn, "/.well-known/oauth-protected-resource")
        metadata = json_response(conn, 200)
        {:ok, Map.put(context, :metadata, metadata)}
      end

      then_ "the resource field identifies the MCP endpoint", context do
        assert Map.has_key?(context.metadata, "resource")
        refute context.metadata["resource"] =~ ~r/^\s*$/
        :ok
      end

      then_ "the authorization_servers field is present and non-empty", context do
        servers = context.metadata["authorization_servers"]
        assert is_list(servers)
        assert length(servers) > 0
        :ok
      end

      then_ "each authorization server entry is a non-empty URL", context do
        assert Enum.all?(context.metadata["authorization_servers"], fn s ->
          is_binary(s) and String.length(s) > 0
        end)
        :ok
      end
    end
  end
end
