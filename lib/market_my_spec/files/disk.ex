defmodule MarketMySpec.Files.Disk do
  @moduledoc """
  Local-filesystem implementation of `MarketMySpec.Files.Behaviour`. Used in
  dev so MCP file tools work without an S3 / MinIO running.

  Files are stored under a configurable root (defaults to
  `tmp/files/`). Account scoping is already applied by the Files context —
  the keys passed to this adapter are already prefixed with
  `accounts/{account_id}/...` so we just write them under the root verbatim.

  Configure via:

      config :market_my_spec, MarketMySpec.Files.Disk,
        root: Path.expand("tmp/files", File.cwd!())
  """

  @behaviour MarketMySpec.Files.Behaviour

  @impl true
  def put(key, body, opts \\ []) when is_binary(key) and is_binary(body) and is_list(opts) do
    path = absolute_path(key)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)

    {:ok, metadata_of(key, body, opts)}
  end

  @impl true
  def get(key) when is_binary(key) do
    case File.read(absolute_path(key)) do
      {:ok, body} -> {:ok, body}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list(prefix) when is_binary(prefix) do
    base = absolute_path(prefix)
    root = root()

    entries =
      base
      |> walk()
      |> Enum.map(fn full_path ->
        relative = Path.relative_to(full_path, root)
        stat = File.stat!(full_path, time: :posix)

        %{
          key: relative,
          size: stat.size,
          last_modified: DateTime.from_unix!(stat.mtime)
        }
      end)

    {:ok, entries}
  end

  @impl true
  def delete(key) when is_binary(key) do
    case File.rm(absolute_path(key)) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp absolute_path(key) do
    Path.join(root(), key)
  end

  defp root do
    config = Application.get_env(:market_my_spec, __MODULE__, [])
    Keyword.get(config, :root, Path.expand("tmp/files", File.cwd!()))
  end

  defp walk(path) do
    case File.stat(path) do
      {:ok, %{type: :regular}} ->
        [path]

      {:ok, %{type: :directory}} ->
        path
        |> File.ls!()
        |> Enum.flat_map(fn entry -> walk(Path.join(path, entry)) end)

      _ ->
        []
    end
  end

  defp metadata_of(key, body, opts) do
    base = %{key: key, size: byte_size(body), last_modified: DateTime.utc_now()}

    case Keyword.get(opts, :content_type) do
      nil -> base
      type -> Map.put(base, :content_type, type)
    end
  end
end
