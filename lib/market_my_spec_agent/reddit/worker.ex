defmodule MarketMySpecAgent.Reddit.Worker do
  @moduledoc """
  Serializes every Reddit fetch the binary performs, on the binary's own
  residential IP.

  Two guarantees, deliberately layered:

    1. **No concurrent requests.** This is a plain GenServer and the fetch
       runs inside `handle_call/3`, so the mailbox is the queue — a second
       request cannot start until the first has returned. This holds
       regardless of how the rate limiter is configured, and regardless of
       how many requests the server dispatches at once.

    2. **At most one request per minute.** `Engagements.Source.Reddit.fetch/2`
       acquires from the `Engagements.RateLimiter` instance the agent
       supervises (`capacity: 1, refill_ms: 60_000` — see
       `MarketMySpecAgent.Application`), and `Engagements.HTTP`'s response
       step feeds Reddit's own `x-ratelimit-*` headers back into it. So the
       floor is 60s and the real gate is whatever window Reddit reports.

  Reddit meters per-IP, and this process is the only thing on this IP
  talking to Reddit — which is the whole reason the fetch lives here rather
  than on the server. The server's limiter governs the server's IP and must
  not also throttle a dispatched fetch (see `Reddit.fetch/2`'s
  `:rate_limit` opt); the pacing that matters happens here.
  """

  use GenServer

  require Logger

  alias MarketMySpec.Engagements.Source.Reddit

  # How long a fetch will wait for a rate-limit token before giving up.
  # Sized above Reddit's ~60s window so a request that arrives just after
  # the window opened still gets served rather than failing spuriously.
  @acquire_timeout 90_000

  # Ceiling for one fetch end-to-end (token wait + HTTP + Req retries).
  # The server's Dispatcher deadline must exceed this so a slow fetch
  # surfaces as a real error rather than a dispatch timeout.
  @call_timeout 120_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Which `RateLimiter` bucket config the agent runs. Single source of truth
  for `MarketMySpecAgent.Application` and for the spex that pin the 1/min
  guarantee, so the two can't drift apart.
  """
  @spec bucket_config() :: map()
  def bucket_config, do: %{reddit: %{capacity: 1, refill_ms: 60_000}}

  @doc """
  Runs one Reddit fetch, queued behind any already in flight.

  Takes the JSON-safe request map built server-side by
  `Reddit.build_search_request/3` or `Reddit.build_thread_request/2` and
  returns `{:ok, %{"status" => …, "body" => …}}` or `{:error, reason}`.
  """
  @spec fetch(map(), GenServer.server()) :: {:ok, map()} | {:error, term()}
  def fetch(request, server \\ __MODULE__) do
    GenServer.call(server, {:fetch, request}, @call_timeout + 5_000)
  catch
    :exit, reason ->
      Logger.warning("[Agent.Reddit.Worker] fetch exited: #{inspect(reason)}")
      {:error, :worker_unavailable}
  end

  @impl true
  def init(opts) do
    {:ok, %{limiter: Keyword.get(opts, :limiter, MarketMySpec.Engagements.RateLimiter)}}
  end

  @impl true
  def handle_call({:fetch, request}, _from, state) do
    {:reply, run(request, state.limiter), state}
  end

  # Reject anything that isn't a well-formed Reddit RSS request before it
  # reaches Req. The base URL is baked into `Engagements.HTTP.reddit_client/0`,
  # so no host ever travels over the channel — but a protocol-relative path
  # ("//evil.example") would still escape the base URL when merged, so the
  # path is validated rather than trusted.
  defp run(%{"path" => path} = request, limiter) when is_binary(path) do
    if valid_path?(path) do
      label = Map.get(request, "label", path)
      Logger.info("[Agent.Reddit.Worker] fetching #{label}")

      case Reddit.fetch(request,
             rate_limit_timeout: @acquire_timeout,
             rate_limit_server: limiter
           ) do
        {:ok, %{"status" => status}} = ok ->
          Logger.info("[Agent.Reddit.Worker] #{label} → #{status}")
          ok

        {:error, reason} = err ->
          Logger.warning("[Agent.Reddit.Worker] #{label} failed: #{inspect(reason)}")
          err
      end
    else
      Logger.warning("[Agent.Reddit.Worker] refused malformed path: #{inspect(path)}")
      {:error, :invalid_request}
    end
  end

  defp run(_request, _limiter), do: {:error, :invalid_request}

  defp valid_path?(path) do
    String.starts_with?(path, "/") and
      not String.starts_with?(path, "//") and
      not String.contains?(path, "://")
  end
end
