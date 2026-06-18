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
end
