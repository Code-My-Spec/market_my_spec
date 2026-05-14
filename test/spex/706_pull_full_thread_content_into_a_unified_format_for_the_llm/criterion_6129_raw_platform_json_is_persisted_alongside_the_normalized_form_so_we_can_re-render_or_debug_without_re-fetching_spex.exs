defmodule MarketMySpecSpex.Story706.Criterion6129ExtendedSpex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6129 (extended) — Raw platform JSON is persisted alongside the normalized
  form so we can re-render or debug without re-fetching.

  Additional coverage: verifies the Thread schema's raw_payload field is truly
  independent and does not require the normalized comment_tree to be populated.

  Interaction surface: Thread schema (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Thread

  spex "raw payload is persisted independently of the normalized form" do
    scenario "Thread accepts raw_payload without a fully normalized comment_tree" do
      given_ "thread attrs with raw_payload but an empty comment_tree", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          source_thread_id: "raw_only_persist_test_002",
          url: "https://reddit.com/r/elixir/comments/raw_only_persist_test_002",
          title: "Thread persisting raw payload without normalization",
          fetched_at: DateTime.utc_now(:second),
          raw_payload: %{"platform" => "reddit", "raw" => true},
          comment_tree: %{}
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "a Thread changeset is built", context do
        changeset = Thread.changeset(%Thread{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected Thread changeset to be valid with just raw_payload and empty comment_tree, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "raw_payload is set on the changeset", context do
        raw = Ecto.Changeset.get_field(context.changeset, :raw_payload)
        assert is_map(raw) and raw["raw"] == true,
               "expected raw_payload to carry the raw flag, got: #{inspect(raw)}"

        {:ok, context}
      end
    end
  end
end
