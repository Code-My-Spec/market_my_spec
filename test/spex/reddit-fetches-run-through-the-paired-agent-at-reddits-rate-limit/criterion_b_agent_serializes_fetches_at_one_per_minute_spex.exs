defmodule MarketMySpecSpex.RedditQueue.AgentSerializesFetchesSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — the agent never issues concurrent Reddit requests, and paces
  them at one per minute.

  The binary runs on a residential IP and that IP is what Reddit meters, so
  the limit has to be enforced there, not only on the server. Two
  guarantees, asserted separately because they fail separately:

    * **Serial** — the worker runs each fetch inside `handle_call/3`, so its
      mailbox is the queue. Pinned by driving two concurrent fetches through
      a Req plug that timestamps entry/exit and asserting the windows are
      disjoint. If the fetch were ever moved into a `Task` (as the channel
      client does for its own call into here), this fails.
    * **1/min** — the worker's limiter is `capacity: 1, refill_ms: 60_000`.
      Pinned by showing a second fetch cannot get a token inside the window.

  Both scenarios drive the real `MarketMySpecAgent.Reddit.Worker` against a
  real `RateLimiter` started with the real `bucket_config/0` — not a
  stand-in — so the assertions are about shipping behavior.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RateLimiter
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpecAgent.Reddit.Worker

  @feed ~s(<?xml version="1.0" encoding="UTF-8"?>) <>
          ~s(<feed xmlns="http://www.w3.org/2005/Atom"><title>t</title></feed>)

  defp unique(prefix), do: :"#{prefix}_#{System.unique_integer([:positive])}"

  # Injects a Req plug into Engagements.HTTP.reddit_client/0 for the
  # duration of `fun`, restoring whatever was there before.
  defp with_plug(plug, fun) do
    previous = Application.get_env(:market_my_spec, :reddit_req_options, [])
    Application.put_env(:market_my_spec, :reddit_req_options, plug: plug, retry: false)

    try do
      fun.()
    after
      Application.put_env(:market_my_spec, :reddit_req_options, previous)
    end
  end

  defp request, do: Reddit.build_search_request(%{identifier: "elixir"}, "phoenix")

  spex "The agent paces Reddit at one request per minute, never concurrently" do
    scenario "Two concurrent fetches never occupy the network at the same time" do
      given_ "a real worker, unthrottled, and a plug that timestamps each request",
             context do
        # Unthrottled bucket isolates SERIALIZATION from rate limiting — this
        # scenario must fail if and only if concurrency leaks.
        {:ok, limiter} = RateLimiter.start_link(name: unique("limiter"), buckets: %{})
        {:ok, worker} = Worker.start_link(name: unique("worker"), limiter: limiter)

        recorder = self()

        plug = fn conn ->
          send(recorder, {:span_start, System.monotonic_time(:microsecond)})
          Process.sleep(40)
          send(recorder, {:span_end, System.monotonic_time(:microsecond)})
          Plug.Conn.resp(conn, 200, @feed)
        end

        {:ok, Map.merge(context, %{worker: worker, plug: plug})}
      end

      when_ "two callers fetch through the worker at the same moment", context do
        results =
          with_plug(context.plug, fn ->
            [
              Task.async(fn -> Worker.fetch(request(), context.worker) end),
              Task.async(fn -> Worker.fetch(request(), context.worker) end)
            ]
            |> Enum.map(&Task.await(&1, 10_000))
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "both succeed and their request windows do not overlap", context do
        assert Enum.all?(context.results, &match?({:ok, %{"status" => 200}}, &1)),
               "both fetches should succeed; got: #{inspect(context.results)}"

        # Drain the recorded span boundaries in arrival order. Serial
        # execution means they must arrive strictly start,end,start,end —
        # any interleaving (start,start,...) proves concurrent requests.
        events = drain_events([])

        assert length(events) == 4,
               "expected 4 span events (2 requests), got: #{inspect(events)}"

        assert [:span_start, :span_end, :span_start, :span_end] == events,
               "requests overlapped — event order was #{inspect(events)}; " <>
                 "the worker must run one Reddit request at a time"

        {:ok, context}
      end
    end

    scenario "A second fetch cannot get a token inside the same 60s window" do
      given_ "a worker wired to a limiter using the agent's real bucket config", context do
        {:ok, limiter} =
          RateLimiter.start_link(name: unique("limiter"), buckets: Worker.bucket_config())

        {:ok, worker} = Worker.start_link(name: unique("worker"), limiter: limiter)

        plug = fn conn -> Plug.Conn.resp(conn, 200, @feed) end

        {:ok, Map.merge(context, %{worker: worker, limiter: limiter, plug: plug})}
      end

      then_ "the configured bucket is one request per minute", context do
        assert Worker.bucket_config() == %{reddit: %{capacity: 1, refill_ms: 60_000}},
               "the agent's Reddit bucket must be 1 request / 60s"

        {:ok, context}
      end

      when_ "one fetch runs, then a second asks for a token", context do
        first = with_plug(context.plug, fn -> Worker.fetch(request(), context.worker) end)

        # The worker's own acquire timeout is 90s; waiting that out would
        # make the spex useless, so the second token request is made
        # directly against the same limiter with a short deadline. Being
        # refused here is exactly what makes the worker's fetch block.
        second = RateLimiter.acquire(:reddit, 200, context.limiter)

        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "the first fetch consumed the window's only token", context do
        assert {:ok, %{"status" => 200}} = context.first

        assert context.second == {:error, :rate_limit_timeout},
               "a second Reddit request inside the 60s window must be held; got: " <>
                 inspect(context.second)

        {:ok, context}
      end
    end
  end

  defp drain_events(acc) do
    receive do
      {:span_start, _} -> drain_events(acc ++ [:span_start])
      {:span_end, _} -> drain_events(acc ++ [:span_end])
    after
      0 -> acc
    end
  end
end
