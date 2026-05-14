defmodule MarketMySpec.McpServers.Engagement.Tools.GetThread do
  @moduledoc """
  MCP tool that fetches and normalizes a full thread by source and thread ID.

  Receives a source type (reddit | elixirforum) and a platform thread ID,
  fetches the full thread via the appropriate source adapter, and returns
  a normalized thread structure including title, OP body, comment tree,
  scores, author handles, and timestamps.

  NOTE: This is a scaffold. The fetch implementation is pending the source
  adapters (Story 706 prerequisites).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response

  schema do
    field :source, :string, required: true, doc: "Source type: reddit | elixirforum"
    field :thread_id, :string, required: true, doc: "Platform-specific thread ID"
  end

  @impl true
  def execute(%{source: source, thread_id: thread_id}, frame) do
    response =
      Response.tool()
      |> Response.text(
        Jason.encode!(%{
          thread_id: thread_id,
          source: source,
          title: "Thread #{thread_id}",
          op_body: "",
          comments: []
        })
      )

    {:reply, response, frame}
  end
end
