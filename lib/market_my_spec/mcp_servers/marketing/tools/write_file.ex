defmodule MarketMySpec.McpServers.Marketing.Tools.WriteFile do
  @moduledoc """
  MCP tool that writes (or overwrites) a file into the caller's account workspace.

  The path is account-relative (e.g. `marketing/05_positioning.md`).
  The account prefix is resolved from the current scope's `active_account_id`.

  For new (non-existent) paths, the write proceeds unconditionally.
  For existing paths, the caller must have called `read_file` on the same path
  in the current session before overwriting — otherwise an error is returned.
  This read-before-overwrite gate prevents blind clobbers.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Files

  schema do
    field :path, :string, required: true, doc: "Account-relative path to write (e.g. marketing/05_positioning.md)"
    field :content, :string, required: true, doc: "File content to write"
  end

  @impl true
  def execute(%{path: path, content: content}, frame) do
    scope = frame.assigns.current_scope

    case file_exists?(scope, path) do
      true ->
        if path_was_read?(frame, path) do
          do_write(scope, path, content, frame)
        else
          {:reply, Response.tool() |> Response.error("Read required before overwriting existing file: #{path}"), frame}
        end

      false ->
        do_write(scope, path, content, frame)
    end
  end

  defp file_exists?(scope, path) do
    case Files.get(scope, path) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp path_was_read?(frame, path) do
    read_paths = Map.get(frame.assigns, :read_paths, MapSet.new())
    MapSet.member?(read_paths, path)
  end

  defp do_write(scope, path, content, frame) do
    case Files.put(scope, path, content) do
      {:ok, _metadata} ->
        {:reply, Response.tool() |> Response.text("Written: #{path}"), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error("Failed to write #{path}: #{format_error(reason)}"), frame}
    end
  end

  defp format_error(:no_active_account), do: "no active account in session"
  defp format_error(:invalid_path), do: "invalid path"
  defp format_error(other), do: inspect(other)
end
