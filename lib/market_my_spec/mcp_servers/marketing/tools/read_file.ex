defmodule MarketMySpec.McpServers.Marketing.Tools.ReadFile do
  @moduledoc """
  MCP tool that reads a file from the caller's account workspace.

  The path is account-relative (e.g. `marketing/05_positioning.md`).
  Returns the raw file content as text. Returns an error response if the
  file does not exist or if no active account is present in the scope.

  On success, records the path in `frame.assigns.read_paths` (a `MapSet`)
  so that downstream write, edit, and delete tools can enforce the
  read-before-overwrite gate.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Files

  schema do
    field :path, :string, required: true, doc: "Account-relative path to read (e.g. marketing/05_positioning.md)"
  end

  @impl true
  def execute(%{path: path}, frame) do
    scope = frame.assigns.current_scope

    case Files.get(scope, path) do
      {:ok, body} ->
        updated_frame = record_read(frame, path)
        {:reply, Response.tool() |> Response.text(body), updated_frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("File not found: #{path}"), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error("Failed to read #{path}: #{format_error(reason)}"), frame}
    end
  end

  defp record_read(frame, path) do
    read_paths = Map.get(frame.assigns, :read_paths, MapSet.new())
    updated_assigns = Map.put(frame.assigns, :read_paths, MapSet.put(read_paths, path))
    %{frame | assigns: updated_assigns}
  end

  defp format_error(:no_active_account), do: "no active account in session"
  defp format_error(:invalid_path), do: "invalid path"
  defp format_error(other), do: inspect(other)
end
