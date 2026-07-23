defmodule MarketMySpecSpex.Story612.Criterion5692Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5692 — Metadata document missing endpoints fails discovery

  Quality gate: the deployed well-known metadata document must contain all
  RFC 8414 required fields with non-empty values. If any are absent or blank,
  this spec fails and the server is considered unfit to ship.
  """

  use MarketMySpecSpex.Case

  spex "OAuth metadata document completeness" do
    scenario "the well-known metadata document contains all required fields" do
      given_ "the OAuth authorization server metadata endpoint", context do
        {:ok, context}
      end

      when_ "the metadata document is requested", context do
        conn = get(context.conn, "/.well-known/oauth-authorization-server")
        metadata = json_response(conn, 200)
        {:ok, Map.put(context, :metadata, metadata)}
      end

      then_ "the issuer field is present and non-empty", context do
        assert Map.has_key?(context.metadata, "issuer")
        refute context.metadata["issuer"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "the authorization_endpoint field is present and non-empty", context do
        assert Map.has_key?(context.metadata, "authorization_endpoint")
        refute context.metadata["authorization_endpoint"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "the token_endpoint field is present and non-empty", context do
        assert Map.has_key?(context.metadata, "token_endpoint")
        refute context.metadata["token_endpoint"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "the registration_endpoint field is present and non-empty", context do
        assert Map.has_key?(context.metadata, "registration_endpoint")
        refute context.metadata["registration_endpoint"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "PKCE with S256 is listed in code_challenge_methods_supported", context do
        methods = context.metadata["code_challenge_methods_supported"]
        assert is_list(methods)
        assert "S256" in methods
        {:ok, context}
      end
    end
  end
end
