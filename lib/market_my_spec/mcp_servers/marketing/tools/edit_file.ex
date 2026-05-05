defmodule MarketMySpec.McpServers.Marketing.Tools.EditFile do
  @moduledoc """
  MCP tool that performs an exact-string replacement within a file in the
  caller's account workspace.

  Replaces the first occurrence of `old_string` with `new_string` in the named
  file. When `replace_all` is `true`, every occurrence is replaced.

  Requires a prior `read_file` call on the same path in the current session
  (read-before-edit gate). Returns an error when:
    - The file does not exist (not_found takes priority over the gate).
    - The path exists but has not been read in this session.
    - `old_string` is not found in the file body.
    - `old_string` appears more than once and `replace_all` is `false`.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Files

  schema do
    field :path, :string, required: true, doc: "Account-relative path to edit"
    field :old_string, :string, required: true, doc: "Exact string to find and replace"
    field :new_string, :string, required: true, doc: "Replacement string"
    field :replace_all, :boolean, required: false, doc: "When true, replace every occurrence; default false"
  end

  @impl true
  def execute(params, frame) do
    path = params.path
    scope = frame.assigns.current_scope

    case Files.get(scope, path) do
      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("File not found: #{path}"), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error("Failed to read #{path}: #{format_error(reason)}"), frame}

      {:ok, _body} ->
        handle_gated_edit(params, frame, scope, path)
    end
  end

  defp handle_gated_edit(params, frame, scope, path) do
    if path_was_read?(frame, path) do
      old_string = params.old_string
      new_string = params.new_string
      replace_all = Map.get(params, :replace_all, false)
      perform_edit(frame, scope, path, old_string, new_string, replace_all)
    else
      {:reply, Response.tool() |> Response.error("Read required before editing existing file: #{path}"), frame}
    end
  end

  defp perform_edit(frame, scope, path, old_string, new_string, replace_all) do
    case Files.edit(scope, path, old_string, new_string, replace_all: replace_all) do
      {:ok, _new_body} ->
        {:reply, Response.tool() |> Response.text("Edited: #{path}"), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("File not found: #{path}"), frame}

      {:error, :string_not_found} ->
        {:reply, Response.tool() |> Response.error("String not found in #{path}: #{inspect(old_string)}"), frame}

      {:error, :not_unique} ->
        {:reply,
         Response.tool()
         |> Response.error(
           "old_string appears multiple times in #{path}; set replace_all=true to replace all occurrences"
         ), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error("Failed to edit #{path}: #{format_error(reason)}"), frame}
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
