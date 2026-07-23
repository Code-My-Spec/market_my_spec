defmodule MarketMySpecWeb.AgentVersionController do
  @moduledoc """
  Public version-check endpoint for the MMS Agent binary's phone-home
  update check. The binary GETs this on every CLI invocation and prints
  a "v X.Y.Z is available, run brew upgrade" notice if `latest` is newer
  than its compiled-in version.

  No auth — the binary may not yet be paired. No state — pure config read.
  Latest version is bumped via `config :market_my_spec, :agent_latest_version`
  by the release workflow on every tag push.
  """

  use MarketMySpecWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      "latest" => Application.get_env(:market_my_spec, :agent_latest_version, "0.1.0"),
      "min_supported" =>
        Application.get_env(:market_my_spec, :agent_min_supported_version, "0.1.0")
    })
  end
end
