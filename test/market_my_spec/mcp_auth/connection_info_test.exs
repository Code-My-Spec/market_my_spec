defmodule MarketMySpec.McpAuth.ConnectionInfoTest do
  use ExUnit.Case, async: true

  alias MarketMySpec.McpAuth.ConnectionInfo

  describe "build/1" do
    test "returns a map with server_url and install_command" do
      result = ConnectionInfo.build("https://marketmyspec.com")

      assert %{server_url: _, install_command: _} = result
    end

    test "appends /mcp to the base URL to form the server_url" do
      assert %{server_url: "https://marketmyspec.com/mcp"} =
               ConnectionInfo.build("https://marketmyspec.com")
    end

    test "embeds the server_url in the install command" do
      %{server_url: server_url, install_command: install_command} =
        ConnectionInfo.build("https://marketmyspec.com")

      assert String.contains?(install_command, server_url)
    end

    test "install command starts with 'claude mcp add'" do
      %{install_command: install_command} = ConnectionInfo.build("https://marketmyspec.com")

      assert String.starts_with?(install_command, "claude mcp add ")
    end

    test "install command includes the server name 'market-my-spec'" do
      %{install_command: install_command} = ConnectionInfo.build("https://marketmyspec.com")

      assert String.contains?(install_command, "market-my-spec")
    end

    test "works with localhost URL including port" do
      %{server_url: server_url, install_command: install_command} =
        ConnectionInfo.build("http://localhost:4000")

      assert server_url == "http://localhost:4000/mcp"
      assert install_command == "claude mcp add market-my-spec http://localhost:4000/mcp"
    end

    test "produces the canonical install command for the production URL" do
      %{install_command: install_command} =
        ConnectionInfo.build("https://marketmyspec.com")

      assert install_command ==
               "claude mcp add market-my-spec https://marketmyspec.com/mcp"
    end

    test "raises ArgumentError for empty string" do
      assert_raise ArgumentError, fn -> ConnectionInfo.build("") end
    end

    test "raises ArgumentError for non-binary input" do
      assert_raise ArgumentError, fn -> ConnectionInfo.build(nil) end
    end
  end
end
