defmodule MarketMySpec.McpAuth.ConnectionInfoTest do
  use ExUnit.Case, async: true

  alias MarketMySpec.McpAuth.ConnectionInfo

  @base_url Application.compile_env(:market_my_spec, :base_url, "http://localhost:4000")

  describe "server_url/0" do
    test "returns the base URL with /mcp appended" do
      assert ConnectionInfo.server_url() == @base_url <> "/mcp"
    end

    test "returns a binary string" do
      assert is_binary(ConnectionInfo.server_url())
    end
  end

  describe "install_command/0" do
    test "returns the Claude Code CLI command including the server URL" do
      assert ConnectionInfo.install_command() ==
               "claude mcp add market-my-spec #{@base_url}/mcp"
    end

    test "starts with the claude mcp add prefix" do
      assert String.starts_with?(ConnectionInfo.install_command(), "claude mcp add")
    end
  end

  describe "setup_info/0" do
    test "returns a map with server_url and install_command keys" do
      info = ConnectionInfo.setup_info()
      assert is_map(info)
      assert Map.has_key?(info, :server_url)
      assert Map.has_key?(info, :install_command)
    end

    test "server_url matches server_url/0" do
      assert ConnectionInfo.setup_info().server_url == ConnectionInfo.server_url()
    end

    test "install_command matches install_command/0" do
      assert ConnectionInfo.setup_info().install_command == ConnectionInfo.install_command()
    end
  end
end
