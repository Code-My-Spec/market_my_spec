defmodule MarketMySpecSpex.Story706.Criterion6179Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6179 — Raw payload is persisted even when normalization fails.

  When the source adapter successfully retrieves the platform JSON but the
  normalization step fails (malformed structure, unexpected schema version),
  the raw payload is still saved to the Thread record with an empty or
  placeholder comment_tree. This ensures the data is not lost and can be
  re-normalized after a fix is deployed.

  At the scaffold stage this verifies the Thread schema accepts a raw_payload
  independently of the normalized fields being fully populated.

  Interaction surface: Thread schema (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Thread

  spex "raw payload is persisted even when normalization fails" do
    scenario "Thread changeset is valid with raw_payload but empty comment_tree" do
      given_ "thread attrs with a raw_payload but an empty/default comment_tree", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          source_thread_id: "raw_persist_fail_norm_001",
          url: "https://reddit.com/r/elixir/comments/raw_persist_fail_norm_001",
          title: "Thread where normalization failed",
          fetched_at: DateTime.utc_now(:second),
          raw_payload: %{
            "platform" => "reddit",
            "raw_data" => "some_unexpected_structure",
            "version" => "unknown"
          },
          comment_tree: %{}
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "a Thread changeset is built", context do
        changeset = Thread.changeset(%Thread{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid (raw_payload alone is sufficient)", context do
        assert context.changeset.valid?,
               "expected changeset to be valid even with empty comment_tree, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "the raw_payload is preserved in the changeset", context do
        raw = Ecto.Changeset.get_field(context.changeset, :raw_payload)

        assert is_map(raw),
               "expected raw_payload to be a map, got: #{inspect(raw)}"

        assert raw["platform"] == "reddit",
               "expected raw_payload to preserve the platform key"

        {:ok, context}
      end

      then_ "the comment_tree defaults to an empty map", context do
        tree = Ecto.Changeset.get_field(context.changeset, :comment_tree)

        assert tree == %{} or is_nil(tree),
               "expected comment_tree to be empty map or nil when normalization fails, " <>
                 "got: #{inspect(tree)}"

        {:ok, context}
      end
    end

    scenario "Thread changeset accepts nil op_body when body normalization fails" do
      given_ "thread attrs missing op_body (normalization failed)", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :elixirforum,
          source_thread_id: "ef_topic_norm_fail_555",
          url: "https://elixirforum.com/t/ef_topic_norm_fail_555",
          title: "ElixirForum thread with failed body normalization",
          fetched_at: DateTime.utc_now(:second),
          raw_payload: %{"topic_id" => 555, "cooked" => nil}
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "a Thread changeset is built without op_body", context do
        changeset = Thread.changeset(%Thread{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid (op_body is optional)", context do
        assert context.changeset.valid?,
               "expected changeset to be valid even without op_body, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "the raw_payload is still present", context do
        raw = Ecto.Changeset.get_field(context.changeset, :raw_payload)

        assert is_map(raw) and raw["topic_id"] == 555,
               "expected raw_payload to be preserved with topic_id=555, got: #{inspect(raw)}"

        {:ok, context}
      end
    end
  end
end
