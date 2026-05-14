defmodule MarketMySpecSpex.Story706.Criterion6126Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6126 — Reddit and ElixirForum (Discourse) JSON are normalized into a
  single internal Thread schema.

  Both source adapters normalize their raw API responses into the shared Thread
  schema shape. The normalized map carries the same keys regardless of whether
  the originating platform is Reddit or ElixirForum, so the LLM and UI never
  branch on source type when rendering thread content.

  Interaction surface: Source adapter functions (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "Reddit and ElixirForum JSON are normalized into a single internal Thread schema" do
    scenario "Reddit.get_thread/2 returns a normalized thread map" do
      given_ "a Reddit venue", context do
        venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "Reddit.get_thread/2 is called with a thread ID", context do
        {:ok, thread} = Reddit.get_thread(context.venue, "abc123")
        {:ok, Map.put(context, :thread, thread)}
      end

      then_ "the thread carries the expected normalized fields", context do
        thread = context.thread
        required_keys = ~w(id source title op_body)a

        Enum.each(required_keys, fn key ->
          assert Map.has_key?(thread, key),
                 "expected Reddit thread to have '#{key}' field, got: #{inspect(Map.keys(thread))}"
        end)

        {:ok, context}
      end

      then_ "the source field identifies the platform as reddit", context do
        assert context.thread.source == "reddit" or context.thread[:source] == :reddit,
               "expected thread source to be reddit, got: #{inspect(context.thread[:source] || context.thread["source"])}"

        {:ok, context}
      end
    end

    scenario "ElixirForum.get_thread/2 returns a normalized thread map" do
      given_ "an ElixirForum venue", context do
        venue = %{source: "elixirforum", identifier: "phoenix-forum", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "ElixirForum.get_thread/2 is called with a thread ID", context do
        {:ok, thread} = ElixirForum.get_thread(context.venue, "12345")
        {:ok, Map.put(context, :thread, thread)}
      end

      then_ "the thread carries the expected normalized fields", context do
        thread = context.thread
        required_keys = ~w(id source title op_body)a

        Enum.each(required_keys, fn key ->
          assert Map.has_key?(thread, key),
                 "expected ElixirForum thread to have '#{key}' field, got: #{inspect(Map.keys(thread))}"
        end)

        {:ok, context}
      end

      then_ "the source field identifies the platform as elixirforum", context do
        assert context.thread.source == "elixirforum" or
                 context.thread[:source] == :elixirforum,
               "expected thread source to be elixirforum, got: #{inspect(context.thread[:source] || context.thread["source"])}"

        {:ok, context}
      end
    end

    scenario "both adapters return a thread with the same top-level shape" do
      given_ "venue fixtures for both platforms", context do
        reddit_venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}

        elixirforum_venue = %{
          source: "elixirforum",
          identifier: "phoenix-forum",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.merge(context, %{reddit_venue: reddit_venue, ef_venue: elixirforum_venue})}
      end

      when_ "both adapters are called", context do
        {:ok, reddit_thread} = Reddit.get_thread(context.reddit_venue, "r123")
        {:ok, ef_thread} = ElixirForum.get_thread(context.ef_venue, "ef456")
        {:ok, Map.merge(context, %{reddit_thread: reddit_thread, ef_thread: ef_thread})}
      end

      then_ "both threads carry the same top-level keys", context do
        reddit_keys = context.reddit_thread |> Map.keys() |> MapSet.new()
        ef_keys = context.ef_thread |> Map.keys() |> MapSet.new()

        common_keys = ~w(id source title op_body)a |> MapSet.new()

        missing_reddit = MapSet.difference(common_keys, reddit_keys)
        missing_ef = MapSet.difference(common_keys, ef_keys)

        assert MapSet.size(missing_reddit) == 0,
               "Reddit thread missing expected keys: #{inspect(MapSet.to_list(missing_reddit))}"

        assert MapSet.size(missing_ef) == 0,
               "ElixirForum thread missing expected keys: #{inspect(MapSet.to_list(missing_ef))}"

        {:ok, context}
      end
    end
  end
end
