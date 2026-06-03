defmodule MarketMySpecSpex.Story733.Criterion6492Spex do
  @moduledoc """
  Story 733 — 6492. When the direct RSS call fails and a user has two
  online agents, the fallback transport must target the most-recently
  connected one. Exercised via the search fallback path (direct 403 →
  agent dispatch).
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  spex "fallback dispatch picks the most recently connected agent" do
    scenario "direct 403; two agents online; the newer one receives the http_request envelope" do
      given_ "a user with two paired+joined agents (agent_b joined last) and a 403 direct cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6492_fallback",
          subreddit: "elixir",
          query: "elixir",
          status: 403
        )

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {agent_a, token_a} = Fixtures.pair_via_ui(conn, user, name: "agent-a")
        {agent_b, token_b} = Fixtures.pair_via_ui(conn, user, name: "agent-b")

        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent_a.id, token_a)
        # ensure agent_b's online_at is strictly later than agent_a's
        Process.sleep(1_100)
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent_b.id, token_b)

        Fixtures.subscribe_to_agent_topic(user.id)
        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.merge(context, %{agent_b: agent_b, frame: frame})}
      end

      when_ "search_engagements is invoked (direct 403 → agent fallback)", context do
        envelope =
          RedditHelpers.with_reddit_cassette("crit_6492_fallback", fn ->
            spawn_link(fn -> SearchEngagements.execute(%{query: "elixir"}, context.frame) end)
            Fixtures.expect_http_request_envelope(3_000)
          end)

        {:ok, Map.put(context, :envelope, envelope)}
      end

      then_ "the fallback http_request envelope targets agent_b (most recently connected)", context do
        assert context.envelope["agent_id"] == context.agent_b.id
        {:ok, context}
      end
    end
  end
end
