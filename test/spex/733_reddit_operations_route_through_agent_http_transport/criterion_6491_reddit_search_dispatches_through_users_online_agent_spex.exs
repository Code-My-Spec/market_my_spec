defmodule MarketMySpecSpex.Story733.Criterion6491Spex do
  @moduledoc """
  Story 733 — 6491. Reddit search is server-first (direct RSS); the paired
  online agent is a FALLBACK used only when the direct call fails. This
  pins that fallback: a 403 from the direct RSS call routes the search
  through the user's online agent, whose reply populates the response.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  spex "direct RSS failure falls back to the user's online agent" do
    scenario "direct call 403s; the search dispatches through the agent and returns its response" do
      given_ "a paired, online agent, a reddit venue, and a cassette where the direct call 403s",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        # Direct server-side RSS deterministically fails (403) so the
        # orchestrator falls back to the agent transport.
        RedditHelpers.build_search_cassette!("crit_6491_fallback",
          subreddit: "elixir",
          query: "elixir",
          status: 403
        )

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)

        Fixtures.subscribe_to_agent_topic(user.id)
        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.merge(context, %{frame: frame})}
      end

      when_ "search_engagements is invoked (direct 403 → agent fallback)", context do
        caller = self()

        result =
          RedditHelpers.with_reddit_cassette("crit_6491_fallback", fn ->
            spawn_link(fn ->
              send(
                caller,
                {:tool_result, SearchEngagements.execute(%{query: "elixir"}, context.frame)}
              )
            end)

            envelope = Fixtures.expect_http_request_envelope()

            # The fallback hits Reddit's RSS endpoint through the agent.
            assert (envelope["url"] || envelope[:url]) =~ ".rss"

            Fixtures.respond_to_envelope(
              envelope,
              200,
              %{"content-type" => ["application/atom+xml"]},
              ~s(<?xml version="1.0" encoding="UTF-8"?>) <>
                ~s(<feed xmlns="http://www.w3.org/2005/Atom"><title>elixir: search results</title></feed>)
            )

            receive do
              {:tool_result, r} -> r
            after
              5_000 -> flunk("tool did not return after agent fallback response")
            end
          end)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returned via the agent fallback transport", context do
        {:reply, _response, _frame} = context.result
        {:ok, context}
      end
    end
  end
end
