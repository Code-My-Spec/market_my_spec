# MarketMySpec.Chat.McpToolRegistry

The real ToolRegistry implementation (story 745), keyed by the conversation's type. list_tools/1 returns the ReqLLM.Tool definitions for the chat's type — Problem Discovery chats get the ProblemDiscovery MCP tools, Marketing Strategy chats get the Marketing MCP tools (Anubis components under MarketMySpec.McpServers.*.Tools.*); an untyped/default chat gets none. Each ReqLLM.Tool wraps an Anubis tool: its callback builds an %Anubis.Server.Frame{assigns: %{current_scope: scope}} from the conversation's account and invokes the tool's execute/2, normalizing the response to text. Cross-type and cross-account access are impossible by construction. Swapped in for NullToolRegistry via the :chat_tool_registry_module config the Runner already reads.

## Type

module

## Dependencies

- MarketMySpec.Chat.ToolRegistry
- MarketMySpec.Chat.Conversation
- MarketMySpec.McpServers
