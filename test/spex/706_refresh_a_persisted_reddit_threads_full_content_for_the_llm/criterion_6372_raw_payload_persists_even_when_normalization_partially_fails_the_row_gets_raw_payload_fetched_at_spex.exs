defmodule MarketMySpecSpex.Story706.Criterion6372Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6372 — Raw payload persists even when normalization partially
  fails: the row gets raw_payload + fetched_at, comment_tree falls back
  to its prior value or nil, the normalization error is surfaced in the
  response.

  Cassette returns HTTP 200 with valid post + comments listing but with
  one comment missing required fields. raw_payload + fetched_at update;
  comment_tree falls back to the pre-existing value; response carries
  a normalization_error description.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "Partial normalization failure: raw_payload persists; comment_tree falls back" do
    scenario "Cassette has a malformed comment; raw_payload updates, comment_tree retains prior" do
      given_ "a Thread with a pre-existing comment_tree (3 comments) and a cassette returning 200 with one malformed comment",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        prior_tree = %{
          "children" => [
            %{"author" => "u1", "body" => "Prior 1", "score" => 1, "created_utc" => 1.0, "depth" => 0},
            %{"author" => "u2", "body" => "Prior 2", "score" => 2, "created_utc" => 2.0, "depth" => 0},
            %{"author" => "u3", "body" => "Prior 3", "score" => 3, "created_utc" => 3.0, "depth" => 0}
          ]
        }

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "malform001",
            fetched_at: stale,
            comment_tree: prior_tree
          })

        # Hand-craft a cassette where the comments listing body is structurally
        # valid JSON but missing required per-comment fields (e.g., no `author`,
        # no `body` for one entry — adapter normalization should reject it).
        cassette_dir = "test/cassettes/reddit"
        File.mkdir_p!(cassette_dir)
        path = Path.join(cassette_dir, "crit_6372_malformed.json")

        body_json = [
          %{
            "kind" => "Listing",
            "data" => %{
              "children" => [
                %{
                  "kind" => "t3",
                  "data" => %{
                    "id" => "malform001",
                    "name" => "t3_malform001",
                    "title" => "Refreshed title",
                    "selftext" => "Refreshed OP body",
                    "author" => "op",
                    "score" => 5,
                    "num_comments" => 1,
                    "created_utc" => 1_711_000_000.0,
                    "permalink" => "/r/elixir/comments/malform001/_/",
                    "url" => "https://www.reddit.com/r/elixir/comments/malform001/_/",
                    "subreddit" => "elixir"
                  }
                }
              ],
              "after" => nil,
              "before" => nil
            }
          },
          %{
            "kind" => "Listing",
            "data" => %{
              "children" => [
                # Malformed: missing required fields (no body, no author)
                %{"kind" => "t1", "data" => %{"score" => 1, "depth" => 0}}
              ],
              "after" => nil,
              "before" => nil
            }
          }
        ]

        cassette = %{
          "version" => "1.0",
          "interactions" => [
            %{
              "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "request" => %{
                "method" => "GET",
                "uri" => "https://www.reddit.com/comments/malform001.json",
                "query_string" => URI.encode_query(sort: "confidence", limit: 25),
                "headers" => %{
                  "user-agent" => ["market_my_spec/0.1 by /u/johns10davenport"]
                },
                "body" => "",
                "body_type" => "text"
              },
              "response" => %{
                "status" => 200,
                "headers" => %{"content-type" => ["application/json; charset=UTF-8"]},
                "body_type" => "json",
                "body_json" => body_json
              }
            }
          ]
        }

        File.write!(path, Jason.encode!(cassette, pretty: true))
        ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread, prior_tree: prior_tree})}
      end

      when_ "the agent calls get_thread; cassette returns malformed comment", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6372_malformed", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "raw_payload + fetched_at updated; comment_tree retained from prior; error surfaced",
            context do
        thread = context.payload["thread"] || context.payload

        assert thread["raw_payload"] != nil and thread["raw_payload"] != %{},
               "expected raw_payload populated from the (malformed) Reddit response"

        # comment_tree should fall back to the prior value
        prior_children = context.prior_tree["children"]
        new_tree = thread["comment_tree"]

        new_children =
          cond do
            is_list(new_tree) -> new_tree
            is_map(new_tree) -> Map.get(new_tree, "children", [])
            true -> []
          end

        assert length(new_children) == length(prior_children),
               "expected comment_tree to fall back to prior 3-comment tree, got #{length(new_children)}"

        # Normalization error must be surfaced
        norm_err = context.payload["normalization_error"] || thread["normalization_error"]
        assert norm_err != nil,
               "expected normalization_error in response, got: #{inspect(context.payload)}"

        {:ok, context}
      end
    end
  end
end
