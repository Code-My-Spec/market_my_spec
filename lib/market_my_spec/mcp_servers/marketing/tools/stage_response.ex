defmodule MarketMySpec.McpServers.Marketing.Tools.StageResponse do
  @moduledoc """
  MCP tool that stages a polished comment draft as a Touchpoint for a thread.

  The LLM supplies the thread_id (UUID of the persisted Thread record), a polished
  comment body, and a link_target. The tool:

  1. Looks up the Thread by UUID, scoped to the current account.
  2. Builds the UTM-tracked version of link_target using the thread's source scheme.
  3. If the bare link_target appears in the body, replaces it with the UTM URL.
  4. Persists a staged Touchpoint with the embedded body.
  5. Returns the touchpoint id, the polished body, and the UTM URL so the agent
     can reference the link with tracking parameters in follow-up calls.

  Returns an MCP error if the thread is not found in the account.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.Engagements.Posting

  schema do
    field :thread_id, :string, required: true, doc: "UUID of the persisted Thread record"
    field :body, :string, required: true, doc: "Polished comment body text"
    field :link_target, :string, required: false, doc: "URL to embed as a UTM-tracked link in the body"
  end

  @impl true
  def execute(%{thread_id: thread_id, body: body} = params, frame) do
    scope = frame.assigns.current_scope
    link_target = Map.get(params, :link_target)

    with {:ok, thread} <- Engagements.get_thread_by_id(scope, thread_id),
         {polished_body, utm_link} <- embed_utm(thread, body, link_target),
         {:ok, touchpoint} <- stage_touchpoint(scope, thread, polished_body, link_target) do
      payload =
        %{
          staged: true,
          touchpoint_id: touchpoint.id,
          polished_body: polished_body
        }
        |> maybe_put_utm_link(utm_link)

      response =
        Response.tool()
        |> Response.text(Jason.encode!(payload))

      {:reply, response, frame}
    else
      {:error, :not_found} ->
        error_message =
          "Thread #{thread_id} was not found in your account. " <>
            "Run search_engagements first to ingest threads."

        response =
          Response.tool()
          |> Response.error(error_message)

        {:reply, response, frame}

      {:error, changeset} ->
        error_message = "Touchpoint creation failed: #{inspect(changeset.errors)}"

        response =
          Response.tool()
          |> Response.error(error_message)

        {:reply, response, frame}
    end
  end

  # When no link_target, return body unchanged and nil utm_link
  defp embed_utm(_thread, body, nil), do: {body, nil}

  # With link_target: build UTM URL, embed it in body (if bare URL present), return both
  defp embed_utm(thread, body, link_target) do
    utm_url = Posting.build_utm_url(thread, link_target)
    polished_body = String.replace(body, link_target, utm_url)
    {polished_body, utm_url}
  end

  defp maybe_put_utm_link(payload, nil), do: payload
  defp maybe_put_utm_link(payload, utm_link), do: Map.put(payload, :utm_link, utm_link)

  defp stage_touchpoint(scope, thread, polished_body, link_target) do
    attrs = %{
      thread_id: thread.id,
      polished_body: polished_body,
      link_target: link_target
    }

    Engagements.create_staged_touchpoint(scope, attrs)
  end
end
