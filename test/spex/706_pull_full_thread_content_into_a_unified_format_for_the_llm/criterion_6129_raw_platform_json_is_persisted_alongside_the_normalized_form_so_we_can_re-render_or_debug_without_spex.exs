defmodule MarketMySpecSpex.Story706.Criterion6129Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6129 — Raw platform JSON is persisted alongside the normalized form so
  we can re-render or debug without re-fetching.

  The Thread schema stores both the normalized form (title, op_body, comment_tree)
  and the raw_payload field which holds the unmodified platform API response. This
  ensures that if the normalization logic changes, the raw data is still available
  for re-normalization without hitting the API again.

  Interaction surface: Thread schema (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Thread

  spex "raw platform JSON is persisted alongside the normalized form" do
    scenario "Thread schema has a raw_payload field in its changeset" do
      given_ "a minimal valid thread attributes map", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          source_thread_id: "raw_payload_test_001",
          url: "https://reddit.com/r/elixir/comments/raw_payload_test_001",
          title: "Test thread for raw payload persistence",
          fetched_at: DateTime.utc_now(:second),
          op_body: "Original post content here",
          raw_payload: %{
            "kind" => "Listing",
            "data" => %{"children" => []},
            "platform" => "reddit"
          },
          comment_tree: %{}
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "a Thread changeset is built with a raw_payload", context do
        changeset = Thread.changeset(%Thread{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected changeset to be valid with raw_payload, errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "the raw_payload is present in the changeset changes", context do
        raw_payload = Ecto.Changeset.get_field(context.changeset, :raw_payload)

        assert is_map(raw_payload),
               "expected raw_payload to be a map in the changeset, got: #{inspect(raw_payload)}"

        {:ok, context}
      end

      then_ "the raw_payload field preserves the original platform structure", context do
        raw_payload = Ecto.Changeset.get_field(context.changeset, :raw_payload)

        assert raw_payload["platform"] == "reddit",
               "expected raw_payload to preserve original platform data, got: #{inspect(raw_payload)}"

        {:ok, context}
      end
    end

    scenario "Thread schema accepts raw_payload alongside normalized comment_tree" do
      given_ "thread attrs with both raw_payload and comment_tree set", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :elixirforum,
          source_thread_id: "discourse_topic_999",
          url: "https://elixirforum.com/t/discourse_topic_999",
          title: "ElixirForum thread with raw payload",
          fetched_at: DateTime.utc_now(:second),
          raw_payload: %{"topic_id" => 999, "posts_count" => 5},
          comment_tree: %{"posts" => []}
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "a Thread changeset is built", context do
        changeset = Thread.changeset(%Thread{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid and both payload fields are set", context do
        assert context.changeset.valid?,
               "expected changeset to be valid, errors: #{inspect(context.changeset.errors)}"

        raw = Ecto.Changeset.get_field(context.changeset, :raw_payload)
        tree = Ecto.Changeset.get_field(context.changeset, :comment_tree)

        assert is_map(raw), "expected raw_payload to be a map"
        assert is_map(tree), "expected comment_tree to be a map"

        {:ok, context}
      end
    end
  end
end
