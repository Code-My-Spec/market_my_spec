defmodule MarketMySpec.Engagements.ThreadsRepositoryTest do
  use MarketMySpecTest.DataCase, async: true

  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.UsersFixtures

  defp scope_fixture do
    user = UsersFixtures.user_fixture()
    _account = UsersFixtures.account_fixture(user)
    UsersFixtures.user_scope_fixture(user)
  end

  describe "upsert_from_search/3 with over-length values" do
    # Regression: `threads.url`/`threads.title` were `varchar(255)` while the
    # changeset allowed url ≤ 2048 / title ≤ 500. Reddit URLs (slug derived from
    # the post title) routinely exceed 255 chars, so an over-length url passed the
    # changeset and then raised Postgrex `22001 string_data_right_truncation` at
    # insert time — an unhandled raise that crashed the search fan-out and
    # surfaced as `-32603 Server unavailable`. The columns are now `:text`.
    test "persists a candidate whose url exceeds 255 characters" do
      scope = scope_fixture()
      long_slug = String.duplicate("a", 300)

      candidate = %{
        "source_thread_id" => "t3_longurl",
        "url" => "https://www.reddit.com/r/vibecoding/comments/abc/#{long_slug}/",
        "title" => "A normal title"
      }

      assert {:ok, thread} = ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
      assert String.length(thread.url) > 255
    end

    test "persists a candidate whose title exceeds 255 characters" do
      scope = scope_fixture()
      long_title = String.duplicate("word ", 80)

      candidate = %{
        "source_thread_id" => "t3_longtitle",
        "url" => "https://www.reddit.com/r/vibecoding/comments/abc/x/",
        "title" => long_title
      }

      assert {:ok, thread} = ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
      assert String.length(thread.title) > 255
    end

    # A url beyond the changeset's documented ceiling (2048) must degrade to a
    # changeset error — the gate `persist_and_enrich/2` relies on to drop the
    # candidate — rather than raising.
    test "returns {:error, changeset} (no raise) for a url beyond the changeset limit" do
      scope = scope_fixture()
      too_long_url = "https://www.reddit.com/" <> String.duplicate("a", 2100)

      candidate = %{
        "source_thread_id" => "t3_waytoolong",
        "url" => too_long_url,
        "title" => "A normal title"
      }

      assert {:error, %Ecto.Changeset{}} =
               ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
    end
  end

  describe "upsert_from_search/3 recency (last_activity_at)" do
    # The candidate's `recency` is the source's real published timestamp. It
    # must land in last_activity_at so callers can tell a fresh post from an
    # old one — previously it was dropped and recency reflected our crawl time.
    test "persists the candidate's published timestamp to last_activity_at" do
      scope = scope_fixture()

      candidate = %{
        "source_thread_id" => "t3_recent",
        "url" => "https://www.reddit.com/r/vibecoding/comments/abc/x/",
        "title" => "A recent post",
        "recency" => "2026-06-15T12:34:56+00:00"
      }

      assert {:ok, thread} = ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
      assert thread.last_activity_at == ~U[2026-06-15 12:34:56Z]
    end

    test "leaves last_activity_at nil when recency is missing or unparseable" do
      scope = scope_fixture()

      candidate = %{
        "source_thread_id" => "t3_norecency",
        "url" => "https://www.reddit.com/r/vibecoding/comments/abc/y/",
        "title" => "No date"
      }

      assert {:ok, thread} = ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
      assert is_nil(thread.last_activity_at)
    end

    # A search re-run must not clobber a deep-read's true last_activity_at
    # (newest comment) by writing back the older post date. last_activity_at is
    # set on insert only, so a conflicting upsert leaves it untouched.
    test "a re-run does not downgrade an existing last_activity_at" do
      scope = scope_fixture()

      candidate = %{
        "source_thread_id" => "t3_deepread",
        "url" => "https://www.reddit.com/r/vibecoding/comments/abc/z/",
        "title" => "Has activity",
        "recency" => "2026-06-10T00:00:00+00:00"
      }

      assert {:ok, thread} = ThreadsRepository.upsert_from_search(scope, :reddit, candidate)

      # Simulate a deep read advancing last_activity_at to a newer comment time.
      {:ok, _} =
        thread
        |> Ecto.Changeset.change(last_activity_at: ~U[2026-06-17 09:00:00Z])
        |> MarketMySpec.Repo.update()

      # A later search sees an older post date; it must not overwrite the newer
      # deep-read value.
      assert {:ok, rerun} =
               ThreadsRepository.upsert_from_search(scope, :reddit, %{
                 candidate
                 | "recency" => "2026-06-10T00:00:00+00:00"
               })

      assert rerun.last_activity_at == ~U[2026-06-17 09:00:00Z]
    end
  end
end
