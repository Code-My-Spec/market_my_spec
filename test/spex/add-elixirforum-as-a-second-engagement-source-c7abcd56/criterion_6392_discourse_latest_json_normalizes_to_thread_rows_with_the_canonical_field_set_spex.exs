defmodule MarketMySpecSpex.Story714.Criterion6392Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6392 — Discourse `/c/<slug>/<id>/l/latest.json` normalizes
  to Thread rows with the canonical field set.

  Field map: topic.id → source_thread_id, title → title, slug →
  permalink basis, posts_count or reply_count → reply_count,
  last_posted_at → last_activity_at, excerpt → snippet, views →
  score-ish.

  Test infrastructure: ReqCassette via `with_elixirforum_cassette/2`
  (ElixirForum-only).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.ElixirForumHelpers
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "Discourse latest.json → canonical candidate" do
    scenario "Recorded Discourse topic → candidate carries canonical field set" do
      given_ "one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_elixirforum_cassette(
            "crit_6392_discourse_normalize",
            fn -> SearchEngagements.execute(%{query: "phoenix"}, context.frame) end
          )

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "forum candidate carries title, source=elixirforum, url, reply_count, recency, snippet",
            context do
        candidates = context.payload["candidates"] || []

        forum =
          Enum.find(candidates, fn c -> to_string(c["source"] || c[:source]) == "elixirforum" end)

        assert forum, "expected one ElixirForum candidate; got #{inspect(candidates)}"

        assert is_binary(forum["title"]) and String.length(forum["title"]) > 0,
               "expected non-empty title"

        assert to_string(forum["source"]) == "elixirforum"

        url = forum["url"] || ""
        assert is_binary(url) and String.contains?(url, "elixirforum.com"),
               "expected url on elixirforum.com; got: #{inspect(url)}"

        assert is_integer(forum["reply_count"]),
               "expected integer reply_count; got: #{inspect(forum["reply_count"])}"

        assert forum["recency"] != nil, "expected recency populated from last_posted_at"

        assert is_binary(forum["snippet"]), "expected snippet from excerpt"

        {:ok, context}
      end
    end
  end
end
