defmodule MarketMySpecAgent.VersionCheck do
  @moduledoc """
  Phone-home version check against `<server_url>/api/agent/version`.

  Called from `MarketMySpecAgent.CLI` on every invocation; prints a
  one-liner notice if the server reports a newer version than the one
  baked into this binary. Cached to `~/.mms-agent/version_check.json`
  with a 24h TTL so we don't hammer the server.

  Soft failure by design — if the server is unreachable, the agent's
  CLI flow is not affected (the agent might be paired against a server
  that's down, or running offline, or behind a VPN). Errors are logged
  and swallowed.
  """

  alias MarketMySpecAgent.Auth

  @cache_filename "version_check.json"
  @ttl_ms 24 * 60 * 60 * 1_000

  @doc """
  Runs the version check with the configured cache. Prints a notice to
  stderr if a newer version is available; otherwise silent. Returns
  `:ok` regardless of outcome.
  """
  def maybe_notify, do: maybe_notify(current_version(), default_server_url())

  @doc false
  def maybe_notify(current, server_url) when is_binary(server_url) do
    case latest_version(server_url) do
      {:ok, latest} ->
        if newer?(latest, current) do
          IO.puts(
            :stderr,
            "Notice: mms-agent v#{latest} is available. Run: brew upgrade mms-agent"
          )
        end

      _ ->
        :ok
    end

    :ok
  end

  def maybe_notify(_current, _server_url), do: :ok

  defp latest_version(server_url) do
    case read_cache() do
      {:fresh, latest} ->
        {:ok, latest}

      _stale_or_missing ->
        fetch_and_cache(server_url)
    end
  end

  defp fetch_and_cache(server_url) do
    url = String.trim_trailing(server_url, "/") <> "/api/agent/version"

    case Req.get(url, receive_timeout: 2_000, retry: false) do
      {:ok, %{status: 200, body: %{"latest" => latest}}} when is_binary(latest) ->
        write_cache(latest)
        {:ok, latest}

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp read_cache do
    path = cache_path()

    with {:ok, body} <- File.read(path),
         {:ok, %{"latest" => latest, "checked_at_ms" => checked_at}}
         when is_binary(latest) and is_integer(checked_at) <- Jason.decode(body),
         true <- now_ms() - checked_at < @ttl_ms do
      {:fresh, latest}
    else
      _ -> :stale
    end
  end

  defp write_cache(latest) do
    File.mkdir_p!(Auth.dir())

    payload = %{
      "latest" => latest,
      "checked_at_ms" => now_ms()
    }

    File.write!(cache_path(), Jason.encode!(payload))
  rescue
    _ -> :ok
  end

  defp cache_path, do: Path.join(Auth.dir(), @cache_filename)

  defp now_ms, do: System.system_time(:millisecond)

  defp current_version do
    case Application.spec(:market_my_spec, :vsn) do
      nil -> "0.0.0"
      v -> to_string(v)
    end
  end

  defp default_server_url do
    case Auth.read() do
      {:ok, %{"server_url" => server_url}} when is_binary(server_url) ->
        server_url

      _ ->
        System.get_env("MMS_SERVER_URL") ||
          Application.get_env(:market_my_spec, :server_url, "https://marketmyspec.com")
    end
  end

  defp newer?(remote, current) do
    case Version.compare(remote, current) do
      :gt -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
