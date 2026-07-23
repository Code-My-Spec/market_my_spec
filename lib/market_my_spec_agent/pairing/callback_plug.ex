defmodule MarketMySpecAgent.Pairing.CallbackPlug do
  @moduledoc """
  One-shot Plug for the loopback pairing callback. Receives the
  server's redirect at `/callback?token=...&agent_id=...&user_id=...`
  (or `?denied=true`), forwards the params to the waiting caller
  process, and renders a small confirmation page.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: ["callback"]} = conn, %{caller: caller, ref: ref}) do
    conn = fetch_query_params(conn)
    send(caller, {:pair_callback, ref, conn.query_params})

    body =
      if conn.query_params["denied"] == "true" do
        "Pairing denied. You can close this tab."
      else
        "Pairing complete. You can close this tab."
      end

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end
end
