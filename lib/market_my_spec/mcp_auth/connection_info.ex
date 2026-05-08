defmodule MarketMySpec.McpAuth.ConnectionInfo do
  @moduledoc """
  Builds the setup-guide payload consumed by McpSetupLive.

  Given a base URL (typically from `MarketMySpecWeb.Endpoint.url/0`), produces
  the server URL and install command a user needs to connect Claude Code to the
  MCP server via OAuth.

  This module is intentionally pure — it performs no I/O and carries no state.
  All inputs are explicit, making the payload easy to test and reason about in
  isolation from the web layer.
  """

  @mcp_path "/mcp"
  @server_name "market-my-spec"

  @typedoc "Setup-guide payload consumed by McpSetupLive."
  @type t :: %{
          server_url: String.t(),
          install_command: String.t()
        }

  @doc """
  Builds the connection-info payload for the given base URL.

  The `base_url` is the scheme + host (+ optional port) string — e.g.
  `"https://marketmyspec.com"` or `"http://localhost:4000"`. It must be a
  non-empty binary; any other input raises `ArgumentError`.

  Returns a map with:

  - `:server_url` — the MCP endpoint URL (`<base_url>/mcp`)
  - `:install_command` — the `claude mcp add` command the user pastes into
    their terminal

  ## Examples

      iex> ConnectionInfo.build("https://marketmyspec.com")
      %{
        server_url: "https://marketmyspec.com/mcp",
        install_command: "claude mcp add market-my-spec https://marketmyspec.com/mcp"
      }

      iex> ConnectionInfo.build("http://localhost:4000")
      %{
        server_url: "http://localhost:4000/mcp",
        install_command: "claude mcp add market-my-spec http://localhost:4000/mcp"
      }

  """
  @spec build(String.t()) :: t()
  def build(base_url) when is_binary(base_url) and byte_size(base_url) > 0 do
    server_url = base_url <> @mcp_path

    %{
      server_url: server_url,
      install_command: "claude mcp add #{@server_name} #{server_url}"
    }
  end

  def build(base_url) do
    raise ArgumentError,
          "base_url must be a non-empty binary, got: #{inspect(base_url)}"
  end
end
