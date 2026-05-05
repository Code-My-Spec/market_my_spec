defmodule MarketMySpec.McpAuth.ConnectionInfo do
  @moduledoc """
  Builds setup-guide payload (server URL, OAuth flow steps, install command)
  consumed by McpSetupLive.

  Base URL comes from `MarketMySpecWeb.Endpoint.url/0` at request time so
  the install command reflects whatever port/host the server is actually
  bound to (4008 in dev, https://app.marketmyspec.com in prod, etc.) —
  not a hardcoded default.
  """

  @mcp_path "/mcp"

  @type connection_info :: %{
          server_url: String.t(),
          install_command: String.t()
        }

  @doc "Returns the MCP server URL — runtime base URL with the `/mcp` path appended."
  @spec server_url() :: String.t()
  def server_url do
    base_url() <> @mcp_path
  end

  @doc "Returns the Claude Code CLI command to install this server as an MCP plugin."
  @spec install_command() :: String.t()
  def install_command do
    "claude mcp add market-my-spec #{server_url()}"
  end

  @doc "Returns the setup-guide payload consumed by McpSetupLive."
  @spec setup_info() :: connection_info()
  def setup_info do
    %{
      server_url: server_url(),
      install_command: install_command()
    }
  end

  defp base_url do
    Application.get_env(:market_my_spec, :base_url, "http://localhost:4000")
  end
end
