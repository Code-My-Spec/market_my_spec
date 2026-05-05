defmodule MarketMySpec.McpServers.Marketing.Tools.DeleteFile do
  @moduledoc """
  MCP tool that deletes a file from the caller's account workspace.

  The path is account-relative (e.g. `marketing/05_positioning.md`).
  Requires a prior `read_file` call on the same path in the current session
  (read-before-delete gate) to prevent accidental deletion of files the agent
  has not inspected.

  Returns an error when:
    - The path has not been read in this session.
    - The file does not exist.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Files

  schema do
    field :path, :string, required: true, doc: "Account-relative path to delete"
  end

  @impl true
  def execute(%{path: path}, frame) do
    if path_was_read?(frame, path) do
      scope = frame.assigns.current_scope

      case Files.delete(scope, path) do
        :ok ->
          {:reply, Response.tool() |> Response.text("Deleted: #{path}"), frame}

        {:error, :not_found} ->
          {:reply, Response.tool() |> Response.error("File not found: #{path}"), frame}

        {:error, reason} ->
          {:reply, Response.tool() |> Response.error("Failed to delete #{path}: #{format_error(reason)}"), frame}
      end
    else
      {:reply, Response.tool() |> Response.error("Read required before deleting file: #{path}"), frame}
    end
  end

  defp path_was_read?(frame, path) do
    read_paths = Map.get(frame.assigns, :read_paths, MapSet.new())
    MapSet.member?(read_paths, path)
  end

  defp format_error(:no_active_account), do: "no active account in session"
  defp format_error(:invalid_path), do: "invalid path"
  defp format_error(other), do: inspect(other)
end
