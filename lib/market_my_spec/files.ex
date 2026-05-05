defmodule MarketMySpec.Files do
  @moduledoc """
  Account-scoped file storage for skill artifacts.

  Artifacts written by the user's MCP-connected agent (via `write_file`,
  `edit_file`, etc.) land here, scoped to the active account's prefix,
  and are surfaced back to the user through the web UI's FilesLive.

  This context is the adapter-facing layer: it resolves an account-relative
  path under `accounts/{account_id}/`, validates the path, and delegates
  to the configured `MarketMySpec.Files.Behaviour` backend (defaults to
  `MarketMySpec.Files.S3`).

  Read-before-edit gating lives above this module in
  `MarketMySpec.McpServers.Marketing.Tools.*`.

  ## Backend configuration

      config :market_my_spec, :files_backend, MarketMySpec.Files.S3

  Swap to a different backend (local disk, GCS, in-memory) by pointing
  the config at any module that implements `MarketMySpec.Files.Behaviour`.
  """

  alias MarketMySpec.Files.Behaviour
  alias MarketMySpec.Users.Scope

  @account_root "accounts"

  @type path :: String.t()
  @type prefix :: String.t()
  @type body :: binary()
  @type opts :: keyword()

  @spec put(Scope.t(), path(), body(), opts()) ::
          {:ok, Behaviour.metadata()} | {:error, term()}
  def put(%Scope{} = scope, path, body, opts \\ [])
      when is_binary(path) and is_binary(body) and is_list(opts) do
    with {:ok, key} <- resolve(scope, path),
         {:ok, metadata} <- backend().put(key, body, opts) do
      {:ok, strip_prefix(metadata, account_prefix(scope))}
    end
  end

  @spec get(Scope.t(), path()) :: {:ok, body()} | {:error, term()}
  def get(%Scope{} = scope, path) when is_binary(path) do
    with {:ok, key} <- resolve(scope, path) do
      backend().get(key)
    end
  end

  @spec list(Scope.t(), prefix()) ::
          {:ok, [Behaviour.metadata()]} | {:error, term()}
  def list(scope, prefix \\ "")

  def list(%Scope{} = scope, prefix) when is_binary(prefix) do
    with {:ok, key_prefix} <- resolve(scope, prefix),
         {:ok, entries} <- backend().list(key_prefix) do
      account_prefix = account_prefix(scope)
      {:ok, Enum.map(entries, &strip_prefix(&1, account_prefix))}
    end
  end

  @spec delete(Scope.t(), path()) :: :ok | {:error, term()}
  def delete(%Scope{} = scope, path) when is_binary(path) do
    with {:ok, key} <- resolve(scope, path) do
      backend().delete(key)
    end
  end

  @doc """
  Performs an exact-string replacement within an existing file.

  Reads the file at `path`, counts occurrences of `old_string`, and writes
  back with `new_string` substituted.

  Options:
    - `:replace_all` (boolean, default `false`) — when `true`, replaces every
      occurrence; when `false`, returns `{:error, :not_unique}` if `old_string`
      appears more than once.

  Returns:
    - `{:ok, new_body}` on success
    - `{:error, :not_found}` when the path does not exist
    - `{:error, :string_not_found}` when `old_string` is not in the body
    - `{:error, :not_unique}` when `old_string` appears more than once and
      `replace_all` is `false`
    - `{:error, reason}` for backend errors
  """
  @spec edit(Scope.t(), path(), String.t(), String.t(), opts()) ::
          {:ok, body()} | {:error, :not_found | :string_not_found | :not_unique | term()}
  def edit(%Scope{} = scope, path, old_string, new_string, opts \\ [])
      when is_binary(path) and is_binary(old_string) and is_binary(new_string) and is_list(opts) do
    replace_all = Keyword.get(opts, :replace_all, false)

    with {:ok, body} <- get(scope, path),
         {:ok, new_body} <- apply_edit(body, old_string, new_string, replace_all) do
      with {:ok, _metadata} <- put(scope, path, new_body) do
        {:ok, new_body}
      end
    end
  end

  defp apply_edit(body, old_string, new_string, replace_all) do
    count = count_occurrences(body, old_string)

    cond do
      count == 0 -> {:error, :string_not_found}
      count > 1 and not replace_all -> {:error, :not_unique}
      true -> {:ok, String.replace(body, old_string, new_string, global: replace_all)}
    end
  end

  defp count_occurrences(body, substring) do
    body
    |> String.split(substring)
    |> length()
    |> Kernel.-(1)
  end

  defp resolve(%Scope{active_account_id: nil}, _path), do: {:error, :no_active_account}

  defp resolve(%Scope{} = scope, path) do
    with :ok <- validate_path(path) do
      {:ok, account_prefix(scope) <> path}
    end
  end

  defp validate_path("/" <> _), do: {:error, :invalid_path}

  defp validate_path(path) do
    case String.contains?(path, "..") do
      true -> {:error, :invalid_path}
      false -> :ok
    end
  end

  defp account_prefix(%Scope{active_account_id: id}), do: "#{@account_root}/#{id}/"

  defp strip_prefix(%{key: key} = entry, prefix) do
    %{entry | key: String.replace_prefix(key, prefix, "")}
  end

  defp backend, do: Application.get_env(:market_my_spec, :files_backend, MarketMySpec.Files.S3)
end
