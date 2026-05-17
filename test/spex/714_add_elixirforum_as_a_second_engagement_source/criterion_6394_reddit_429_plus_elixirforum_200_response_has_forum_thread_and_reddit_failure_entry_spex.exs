defmodule MarketMySpecSpex.Story714.Criterion6394Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6394 — Reddit 429 plus ElixirForum 200: response has the
  ElixirForum thread and a Reddit failure entry.

  Sister to 6285, specialized to the rate-limit case (429). Most
  common cross-source failure mode in production.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2`. Record
  with a real (or forced) Reddit 429 + ElixirForum success.

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

  spex "Reddit 429 + ElixirForum 200 → forum thread + reddit-rate-limit failure entry" do
    scenario "Reddit 429 while ElixirForum returns; envelope has both" do
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
          ElixirForumHelpers.with_mixed_cassette("crit_6394_reddit_429", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "forum candidate present; reddit failure entry present; failure reason indicates rate limit",
            context do
        candidates = context.payload["candidates"] || []
        failures = context.payload["failures"] || []

        forum =
          Enum.find(candidates, fn c -> to_string(c["source"] || c[:source]) == "elixirforum" end)

        assert forum, "expected ElixirForum candidate"

        reddit_failure =
          Enum.find(failures, fn f -> to_string(f["source"] || f[:source]) == "reddit" end)

        assert reddit_failure, "expected reddit failure entry; got: #{inspect(failures)}"

        reason = (reddit_failure["reason"] || reddit_failure[:reason] || "") |> to_string()

        assert reason =~ ~r/rate|429|throttl/i,
               "expected failure reason to indicate rate-limit; got: #{inspect(reason)}"

        {:ok, context}
      end
    end
  end
end
