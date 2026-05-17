defmodule MarketMySpecSpex.Story706.Criterion6381Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6381 — Reddit returns 200 with malformed comment shape;
  raw_payload persists, comment_tree falls back to prior.

  Sister to 6372; pinned via Three Amigos scenario. Cassette returns
  HTTP 200 with a structurally-valid JSON envelope but one comment
  missing required fields. Response: raw_payload + fetched_at updated;
  comment_tree retains the pre-existing 3-comment tree; response carries
  normalization_error.

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

  defp top_level(comment_tree) do
    cond do
      is_list(comment_tree) -> comment_tree
      is_map(comment_tree) -> Map.get(comment_tree, "children", [])
      true -> []
    end
  end

  spex "200 with malformed comment: raw_payload updates; comment_tree falls back; error surfaced" do
    scenario "Pre-existing 3-comment tree retained when refresh comment shape is invalid" do
      given_ "a Thread with prior 3 comments and a cassette returning malformed comment data",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        prior_tree = %{
          "children" => [
            %{"author" => "u1", "body" => "Prior 1", "score" => 1,
              "created_utc" => 1.0, "depth" => 0},
            %{"author" => "u2", "body" => "Prior 2", "score" => 2,
              "created_utc" => 2.0, "depth" => 0},
            %{"author" => "u3", "body" => "Prior 3", "score" => 3,
              "created_utc" => 3.0, "depth" => 0}
          ]
        }

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "malform_6381",
            fetched_at: stale,
            comment_tree: prior_tree
          })

        path = "test/cassettes/reddit/crit_6381_malformed.json"
        File.mkdir_p!("test/cassettes/reddit")

        body_json = [
          %{
            "kind" => "Listing",
            "data" => %{
              "children" => [
                %{
                  "kind" => "t3",
                  "data" => %{
                    "id" => "malform_6381",
                    "name" => "t3_malform_6381",
                    "title" => "Refreshed title",
                    "selftext" => "Refreshed OP body",
                    "author" => "op",
                    "score" => 5,
                    "num_comments" => 1,
                    "created_utc" => 1_711_000_000.0,
                    "permalink" => "/r/elixir/comments/malform_6381/_/",
                    "url" => "https://www.reddit.com/r/elixir/comments/malform_6381/_/",
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
                "uri" => "https://www.reddit.com/comments/malform_6381.json",
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

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           thread: thread,
           prior_count: length(prior_tree["children"])
         })}
      end

      when_ "agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6381_malformed", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "raw_payload updated; comment_tree retains prior 3 comments; normalization_error in envelope",
            context do
        thread = context.payload["thread"] || context.payload

        assert thread["raw_payload"] != nil and thread["raw_payload"] != %{},
               "expected raw_payload populated from the (malformed) response"

        new_children = top_level(thread["comment_tree"])
        assert length(new_children) == context.prior_count,
               "expected comment_tree to fall back to prior #{context.prior_count}-comment tree, got #{length(new_children)}"

        err = context.payload["normalization_error"] || thread["normalization_error"]
        assert err != nil,
               "expected normalization_error in response, got: #{inspect(context.payload)}"

        {:ok, context}
      end
    end
  end
end
