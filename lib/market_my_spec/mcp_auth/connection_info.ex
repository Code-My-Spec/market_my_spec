defmodule MarketMySpec.McpAuth.ConnectionInfo do
  @moduledoc """
  Builds setup-guide payload (server URL, OAuth flow steps, install command)
  consumed by McpSetupLive.

  The base URL is read from application config (`:market_my_spec, :base_url`),
  defaulting to `"http://localhost:4000"`. This is only used for the
  developer-facing setup guide UI — OAuth well-known metadata is generated
  at request time by `OauthController` using `MarketMySpecWeb.Endpoint.url()`
  so it reflects the correct runtime host.
  """

  @mcp_path "/mcp"

  @type connection_info :: %{
          server_url: String.t(),
          install_command: String.t()
        }

  @doc """
  Returns the MCP server URL — the base URL with the `/mcp` path appended.

  ## Examples

      iex> MarketMySpec.McpAuth.ConnectionInfo.server_url()
      "http://localhost:4000/mcp"

  """
  @spec server_url() :: String.t()
  def server_url do
    base_url() <> @mcp_path
  end

  @doc """
  Returns the Claude Code CLI command to install this server as an MCP plugin.

  ## Examples

      iex> MarketMySpec.McpAuth.ConnectionInfo.install_command()
      "claude mcp add market-my-spec http://localhost:4000/mcp"

  """
  @spec install_command() :: String.t()
  def install_command do
    "claude mcp add market-my-spec #{server_url()}"
  end

  @doc """
  Returns the setup-guide payload consumed by McpSetupLive, containing the
  server URL and install command.

  ## Examples

      iex> info = MarketMySpec.McpAuth.ConnectionInfo.setup_info()
      iex> is_binary(info.server_url)
      true
      iex> is_binary(info.install_command)
      true

  """
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
