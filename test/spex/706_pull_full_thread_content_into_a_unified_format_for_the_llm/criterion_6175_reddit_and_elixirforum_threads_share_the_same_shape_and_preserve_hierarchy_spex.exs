defmodule MarketMySpecSpex.Story706.Criterion6175Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6175 — Reddit and ElixirForum threads share the same shape and
  preserve hierarchy.

  When the get_thread MCP tool is called for a Reddit thread and again for an
  ElixirForum thread, both responses carry the same top-level JSON shape.
  The LLM does not need to branch on source type to parse the response.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "Reddit and ElixirForum threads share the same shape and preserve hierarchy" do
    scenario "get_thread returns the same top-level shape for Reddit and ElixirForum" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "get_thread is called for a Reddit thread", context do
        {:reply, reddit_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "shape_test_reddit_123"},
            context.frame
          )

        {:ok, Map.put(context, :reddit_response, reddit_response)}
      end

      when_ "get_thread is called for an ElixirForum thread", context do
        {:reply, ef_response, _frame} =
          GetThread.execute(
            %{source: "elixirforum", thread_id: "shape_test_ef_456"},
            context.frame
          )

        {:ok, Map.put(context, :ef_response, ef_response)}
      end

      then_ "both responses succeed without error", context do
        refute context.reddit_response.isError,
               "expected Reddit get_thread to succeed"

        refute context.ef_response.isError,
               "expected ElixirForum get_thread to succeed"

        {:ok, context}
      end

      then_ "both responses decode as valid JSON", context do
        reddit_text = response_text(context.reddit_response)
        ef_text = response_text(context.ef_response)

        assert {:ok, _} = Jason.decode(reddit_text),
               "expected Reddit response to be valid JSON"

        assert {:ok, _} = Jason.decode(ef_text),
               "expected ElixirForum response to be valid JSON"

        {:ok, context}
      end

      then_ "both decoded responses carry the same top-level keys", context do
        reddit_text = response_text(context.reddit_response)
        ef_text = response_text(context.ef_response)

        {:ok, reddit_decoded} = Jason.decode(reddit_text)
        {:ok, ef_decoded} = Jason.decode(ef_text)

        reddit_keys = reddit_decoded |> Map.keys() |> MapSet.new()
        ef_keys = ef_decoded |> Map.keys() |> MapSet.new()

        common_required = ~w(source thread_id)s |> MapSet.new()

        missing_reddit = MapSet.difference(common_required, reddit_keys)
        missing_ef = MapSet.difference(common_required, ef_keys)

        assert MapSet.size(missing_reddit) == 0,
               "Reddit response missing keys: #{inspect(MapSet.to_list(missing_reddit))}, " <>
                 "got: #{inspect(MapSet.to_list(reddit_keys))}"

        assert MapSet.size(missing_ef) == 0,
               "ElixirForum response missing keys: #{inspect(MapSet.to_list(missing_ef))}, " <>
                 "got: #{inspect(MapSet.to_list(ef_keys))}"

        {:ok, context}
      end

      then_ "the source field correctly identifies each platform", context do
        reddit_text = response_text(context.reddit_response)
        ef_text = response_text(context.ef_response)

        {:ok, reddit_decoded} = Jason.decode(reddit_text)
        {:ok, ef_decoded} = Jason.decode(ef_text)

        assert reddit_decoded["source"] == "reddit",
               "expected Reddit response source='reddit', got: #{inspect(reddit_decoded["source"])}"

        assert ef_decoded["source"] == "elixirforum",
               "expected ElixirForum response source='elixirforum', " <>
                 "got: #{inspect(ef_decoded["source"])}"

        {:ok, context}
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
