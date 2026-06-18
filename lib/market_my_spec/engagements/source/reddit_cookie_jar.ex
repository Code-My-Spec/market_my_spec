defmodule MarketMySpec.Engagements.Source.RedditCookieJar do
  @moduledoc """
  A tiny in-memory cookie jar for the anonymous Reddit RSS client.

  Each `HTTP.reddit_client/0` call builds a *fresh* `%Req.Request{}` with no
  cookies, so without this jar every request reaches Reddit as a brand-new
  cookieless client — which their edge bot-detection treats as suspicious and
  429s after the first hit. This GenServer persists the `Set-Cookie` values
  Reddit hands back (its session/edge cookies) and replays them as a `Cookie`
  header on subsequent requests, so we look like one returning session instead
  of a swarm of anonymous strangers from one IP.

  State is a flat `%{name => value}` map (last write wins). Best-effort: under
  concurrent requests a read can miss a just-written cookie, which is fine —
  the bucket serializes Reddit calls anyway, and a stale cookie just means one
  request looks slightly less established.

  Fails open: if the jar process isn't running (e.g. tests that don't start
  it), `cookie_header/1` returns nil and `store/2` is a no-op, so the client
  behaves exactly as it did before this module existed.
  """

  use GenServer

  # ── Public API ─────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Returns a `Cookie` header value (\"k1=v1; k2=v2\"), or nil if empty/unavailable."
  @spec cookie_header(GenServer.server()) :: String.t() | nil
  def cookie_header(server \\ __MODULE__) do
    GenServer.call(server, :cookie_header)
  catch
    :exit, _ -> nil
  end

  @doc "Merges a list of `Set-Cookie` header values into the jar."
  @spec store([String.t()], GenServer.server()) :: :ok
  def store(set_cookie_values, server \\ __MODULE__) when is_list(set_cookie_values) do
    GenServer.cast(server, {:store, set_cookie_values})
  catch
    :exit, _ -> :ok
  end

  # ── GenServer ──────────────────────────────────────────────────────────

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call(:cookie_header, _from, cookies) when map_size(cookies) == 0 do
    {:reply, nil, cookies}
  end

  def handle_call(:cookie_header, _from, cookies) do
    {:reply, Enum.map_join(cookies, "; ", fn {k, v} -> "#{k}=#{v}" end), cookies}
  end

  @impl true
  def handle_cast({:store, set_cookie_values}, cookies) do
    {:noreply, Enum.reduce(set_cookie_values, cookies, &merge_cookie/2)}
  end

  # A Set-Cookie value is "name=value; Path=/; HttpOnly; ...". We keep only the
  # leading name=value pair and drop the attributes.
  defp merge_cookie(set_cookie, acc) do
    set_cookie
    |> String.split(";", parts: 2)
    |> List.first()
    |> String.split("=", parts: 2)
    |> case do
      [name, value] -> Map.put(acc, String.trim(name), String.trim(value))
      _ -> acc
    end
  end
end
