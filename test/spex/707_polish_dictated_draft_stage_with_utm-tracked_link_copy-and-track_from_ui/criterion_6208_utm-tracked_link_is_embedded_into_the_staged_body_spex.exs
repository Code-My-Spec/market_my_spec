defmodule MarketMySpecSpex.Story707.Criterion6208Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6208 — UTM-tracked link is embedded into the staged body.

  Before persisting the Touchpoint, the app takes the bare link_target and embeds
  it with the correct UTM parameters for the thread's source. The staged polished_body
  contains the UTM-enriched URL, not the bare one.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Posting
  alias MarketMySpecSpex.Fixtures

  spex "UTM-tracked link is embedded into the staged body" do
    scenario "Posting embeds UTM params for a Reddit thread before saving" do
      given_ "an account-scoped user with a Reddit thread fixture", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: "reddit", source_thread_id: "test_thread_001"})

        {:ok, Map.merge(context, %{scope: scope, thread: thread})}
      end

      when_ "the Posting module embeds the UTM link for the body", context do
        bare_link = "https://codemyspec.com"
        polished_body = "Great discussion! CodeMySpec handles requirements-driven dev: #{bare_link}"

        result = Posting.embed_utm_link(context.thread, polished_body, bare_link)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the result body contains UTM parameters from the reddit source scheme", context do
        result = context.result

        embedded_body =
          case result do
            {:ok, body} -> body
            body when is_binary(body) -> body
            other -> flunk("Expected embed_utm_link to return ok tuple or string, got: #{inspect(other)}")
          end

        assert embedded_body =~ "utm_source=reddit",
               "expected embedded body to contain utm_source=reddit, got: #{inspect(embedded_body)}"

        assert embedded_body =~ "utm_medium=engagement",
               "expected embedded body to contain utm_medium=engagement"

        {:ok, context}
      end
    end
  end
end
