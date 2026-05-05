defmodule MarketMySpec.McpServers.Marketing.Tools.ListFiles do
  @moduledoc """
  MCP tool that lists files in the caller's account workspace.

  Returns account-relative keys (the `accounts/{id}/` prefix is never
  exposed to the caller). An optional `prefix` parameter narrows the listing
  to keys that start with the given relative prefix (e.g. `marketing/`).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Files

  schema do
    field :prefix, :string, required: false, doc: "Optional relative prefix to filter results (e.g. marketing/)"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    prefix = Map.get(params, :prefix, "")

    case Files.list(scope, prefix) do
      {:ok, entries} ->
        keys_text = Enum.map_join(entries, "\n", & &1.key)
        {:reply, Response.tool() |> Response.text(keys_text), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error("Failed to list files: #{format_error(reason)}"), frame}
    end
  end

  defp format_error(:no_active_account), do: "no active account in session"
  defp format_error(other), do: inspect(other)
end
