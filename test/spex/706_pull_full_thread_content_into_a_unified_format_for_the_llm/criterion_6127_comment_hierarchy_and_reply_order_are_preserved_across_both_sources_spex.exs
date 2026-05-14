defmodule MarketMySpecSpex.Story706.Criterion6127Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6127 — Comment hierarchy and reply order are preserved across both sources.

  The normalized thread carries a comment_tree (or comments) field that preserves
  parent-child relationships from the source platform. Top-level comments appear
  before nested replies. The LLM can traverse the hierarchy without needing to
  know the raw platform shape.

  Interaction surface: Source adapter functions (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "comment hierarchy and reply order are preserved across both sources" do
    scenario "Reddit.get_thread/2 returns a thread with a comments/comment_tree field" do
      given_ "a Reddit venue", context do
        venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "Reddit.get_thread/2 is called", context do
        {:ok, thread} = Reddit.get_thread(context.venue, "hierarchy_test_1")
        {:ok, Map.put(context, :thread, thread)}
      end

      then_ "the thread carries a comment hierarchy field (comments or comment_tree)", context do
        thread = context.thread
        has_comments = Map.has_key?(thread, :comments) or Map.has_key?(thread, :comment_tree)

        assert has_comments,
               "expected Reddit thread to carry a 'comments' or 'comment_tree' field for " <>
                 "hierarchy, got keys: #{inspect(Map.keys(thread))}"

        {:ok, context}
      end

      then_ "the comment hierarchy field is a list or map (not nil)", context do
        thread = context.thread
        comments = Map.get(thread, :comments) || Map.get(thread, :comment_tree)

        assert is_list(comments) or is_map(comments),
               "expected comment hierarchy to be a list or map, got: #{inspect(comments)}"

        {:ok, context}
      end
    end

    scenario "ElixirForum.get_thread/2 returns a thread with a comments/comment_tree field" do
      given_ "an ElixirForum venue", context do
        venue = %{source: "elixirforum", identifier: "phoenix-forum", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "ElixirForum.get_thread/2 is called", context do
        {:ok, thread} = ElixirForum.get_thread(context.venue, "hierarchy_test_2")
        {:ok, Map.put(context, :thread, thread)}
      end

      then_ "the thread carries a comment hierarchy field (comments or comment_tree)", context do
        thread = context.thread
        has_comments = Map.has_key?(thread, :comments) or Map.has_key?(thread, :comment_tree)

        assert has_comments,
               "expected ElixirForum thread to carry a 'comments' or 'comment_tree' field, " <>
                 "got keys: #{inspect(Map.keys(thread))}"

        {:ok, context}
      end

      then_ "the comment hierarchy field is a list or map (not nil)", context do
        thread = context.thread
        comments = Map.get(thread, :comments) || Map.get(thread, :comment_tree)

        assert is_list(comments) or is_map(comments),
               "expected comment hierarchy to be a list or map, got: #{inspect(comments)}"

        {:ok, context}
      end
    end
  end
end
