defmodule MarketMySpecSpex.Story714.Criterion6397Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6397 — Failure entries carry source, venue_identifier, and
  a human-readable reason.

  Failure entry contract: every entry has `source`, `venue_identifier`,
  and a non-empty `reason` string. Reason is UI/log-surfaceable
  (a sentence, not an inspect of an internal tuple).

  Test infrastructure: ReqCassette via `with_mixed_cassette/2`. Record
  two failure scenarios (Reddit + ElixirForum) into one cassette.

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

  spex "failure entries carry {source, venue_identifier, reason} with non-empty reason" do
    scenario "Reddit failure + ElixirForum failure → 2 entries, both well-formed" do
      given_ "one Reddit venue + one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6397_failure_entry_shape", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "each failure entry carries non-nil source, venue_identifier, and a non-empty reason",
            context do
        failures = context.payload["failures"] || []
        refute Enum.empty?(failures), "expected failure entries; got empty list"
        assert length(failures) == 2, "expected one entry per failing venue (2 total)"

        for f <- failures do
          source = f["source"] || f[:source]
          venue_id = f["venue_identifier"] || f[:venue_identifier]
          reason = f["reason"] || f[:reason]

          assert source != nil, "expected :source key on failure entry; got: #{inspect(f)}"

          assert venue_id != nil,
                 "expected :venue_identifier key on failure entry; got: #{inspect(f)}"

          assert is_binary(reason),
                 "expected :reason to be a string; got: #{inspect(reason)}"

          assert reason != "", "expected :reason non-empty (UI-surfaceable)"
        end

        # Pair-up: reddit failure → elixir venue; forum failure → phoenix venue
        reddit_failure = Enum.find(failures, &(to_string(&1["source"] || &1[:source]) == "reddit"))
        forum_failure = Enum.find(failures, &(to_string(&1["source"] || &1[:source]) == "elixirforum"))

        assert reddit_failure
        assert forum_failure

        assert (reddit_failure["venue_identifier"] || reddit_failure[:venue_identifier]) == "elixir"

        assert (forum_failure["venue_identifier"] || forum_failure[:venue_identifier]) ==
                 "phoenix-forum"

        {:ok, context}
      end
    end
  end
end
