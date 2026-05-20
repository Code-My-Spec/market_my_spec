defmodule MarketMySpecSpex.Story733.Criterion6498Spex do
  @moduledoc """
  Story 733 — Reddit operations route through agent HTTP transport
  Criterion 6498 — ElixirForum HTTP bypasses the agent.

  ElixirForum (Discourse) is a publicly accessible API that does not
  require a residential IP. It must NOT be routed through the agent.
  The spec subscribes to `agents:<user_id>`, calls `search_engagements`
  for an ElixirForum venue, and asserts that NO `http_request` broadcast
  is issued on the agents channel. The bypass happens at the source
  adapter layer (ElixirForum.search/3 uses its own HTTP client, not
  Dispatcher).

  Surface: MCP tool execution (SearchEngagements) + Endpoint PubSub
           subscription confirming no agent broadcast is emitted.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.ElixirForumHelpers
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp build_elixirforum_cassette!(name) do
    cassette_dir = "test/cassettes/elixirforum"
    File.mkdir_p!(cassette_dir)
    path = Path.join(cassette_dir, name <> ".json")

    cassette = %{
      "version" => "1.0",
      "interactions" => [
        # categories.json lookup (initial cache miss).
        %{
          "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "request" => %{
            "method" => "GET",
            "uri" => "https://elixirforum.com/categories.json",
            "query_string" => "",
            "headers" => %{},
            "body" => "",
            "body_type" => "text"
          },
          "response" => %{
            "status" => 200,
            "headers" => %{"content-type" => ["application/json"]},
            "body_type" => "json",
            "body_json" => %{
              "category_list" => %{
                "categories" => [
                  %{"id" => 7, "slug" => "elixir"}
                ]
              }
            }
          }
        },
        # Latest topics for category.
        %{
          "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "request" => %{
            "method" => "GET",
            "uri" => "https://elixirforum.com/c/elixir/7/l/latest.json",
            "query_string" => "",
            "headers" => %{},
            "body" => "",
            "body_type" => "text"
          },
          "response" => %{
            "status" => 200,
            "headers" => %{"content-type" => ["application/json"]},
            "body_type" => "json",
            "body_json" => %{
              "topic_list" => %{
                "topics" => [
                  %{
                    "id" => 9001,
                    "title" => "ElixirForum bypass topic",
                    "slug" => "elixirforum-bypass-topic",
                    "reply_count" => 2,
                    "views" => 50,
                    "last_posted_at" => "2024-01-01T00:00:00.000Z",
                    "excerpt" => "Test topic"
                  }
                ]
              }
            }
          }
        }
      ]
    }

    File.write!(path, Jason.encode!(cassette, pretty: true))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

    # Clear any cached category slug→id mapping between tests.
    try do
      :persistent_term.erase(
        {MarketMySpec.Engagements.Source.ElixirForum, :categories_by_slug}
      )
    rescue
      _ -> :ok
    end

    :ok
  end

  spex "ElixirForum HTTP bypasses the agent" do
    scenario "an ElixirForum venue search does not broadcast http_request on the agents topic" do
      given_ "an account with an enabled ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum, identifier: "elixir", enabled: true
        })

        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "search_engagements is called for the ElixirForum venue", context do
        user_id = context.scope.user.id
        topic = "agents:#{user_id}"

        MarketMySpecWeb.Endpoint.subscribe(topic)

        build_elixirforum_cassette!("crit_6498_bypass")

        tool_result =
          ElixirForumHelpers.with_elixirforum_cassette("crit_6498_bypass", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        # Give any async broadcast a short window to arrive.
        agent_broadcast_received =
          receive do
            %Phoenix.Socket.Broadcast{event: "http_request"} -> true
          after
            300 -> false
          end

        {:ok,
         Map.merge(context, %{
           tool_result: tool_result,
           agent_broadcast_received: agent_broadcast_received
         })}
      end

      then_ "no http_request broadcast was issued on the agents channel", context do
        refute context.agent_broadcast_received,
               "expected ElixirForum search to bypass the agent entirely, " <>
                 "but an http_request was broadcast on agents:#{context.scope.user.id}"

        {:ok, context}
      end

      then_ "the tool returns ElixirForum candidates directly (no agent involved)", context do
        {:reply, response, _frame} = context.tool_result

        text =
          response.content
          |> List.wrap()
          |> Enum.map_join("\n", fn
            %{"text" => t} -> t
            %{text: t} -> t
            other -> inspect(other)
          end)

        payload = Jason.decode!(text)

        assert Map.has_key?(payload, "candidates"),
               "expected candidates key in ElixirForum search response; " <>
                 "got: #{inspect(Map.keys(payload))}"

        {:ok, context}
      end
    end
  end
end
