defmodule MarketMySpecSpex.Story707.Criterion6461Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as a Touchpoint
  Criterion 6461 — Thread schema gains a `synopsis` text field (nullable),
  persisted in the threads table.

  Verifies the schema field is castable, nullable (a newly-inserted Thread
  has synopsis = nil), and round-trips through Repo when set.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures

  spex "threads.synopsis exists, is nullable, and persists" do
    scenario "create a thread without synopsis, then set it via changeset and reload" do
      given_ "a fresh thread with no synopsis", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "syn461"})
        {:ok, Map.merge(context, %{scope: scope, thread: thread})}
      end

      when_ "we set synopsis via changeset and reload from the database", context do
        {:ok, updated} =
          context.thread
          |> Thread.changeset(%{synopsis: "OP asks how to integrate Ash incrementally."})
          |> Repo.update()

        reloaded = Repo.get!(Thread, updated.id)
        {:ok, Map.merge(context, %{updated: updated, reloaded: reloaded})}
      end

      then_ "the initial thread had nil synopsis and the reloaded thread carries the new value", context do
        assert context.thread.synopsis == nil,
               "expected freshly-inserted thread.synopsis to be nil; got: #{inspect(context.thread.synopsis)}"

        assert context.reloaded.synopsis == "OP asks how to integrate Ash incrementally.",
               "expected reloaded thread.synopsis to round-trip; got: #{inspect(context.reloaded.synopsis)}"

        {:ok, context}
      end
    end
  end
end
