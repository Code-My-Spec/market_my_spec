defmodule MarketMySpec.Chat.McpToolRegistry do
  @moduledoc """
  The real `ToolRegistry` implementation (story 745), keyed by the
  conversation's `type`.

  `list_tools/1` returns `ReqLLM.Tool` definitions for the chat's type —
  Problem Discovery chats get the ProblemDiscovery MCP tools, Marketing Strategy
  chats get the Marketing MCP tools (Anubis components under
  `MarketMySpec.McpServers.*.Tools.*`); an untyped chat gets none.

  Each `ReqLLM.Tool` wraps an Anubis tool component: its name, description and
  parameter schema come straight from the component (`name/0`,
  `__description__/0`, `input_schema/0` — a JSON Schema map ReqLLM accepts
  directly), and its callback builds an `Anubis.Server.Frame` carrying the
  conversation's account scope, invokes the component's `execute/2`, and
  normalizes the response to text. Because the scope is the conversation's
  account, cross-type and cross-account access are impossible by construction.

  Swapped in for `NullToolRegistry` via the `:chat_tool_registry_module` config
  the `Runner` already reads.
  """

  @behaviour MarketMySpec.Chat.ToolRegistry

  alias Anubis.Server.Frame
  alias MarketMySpec.Chat.Conversation
  alias MarketMySpec.Users.Scope

  @problem_discovery_tools [
    MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.ListPostingsForCandidate,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.LabelCandidate,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.MergeCandidates,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.SplitCandidate,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.SetPainDescriptor,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate,
    MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard
  ]

  @marketing_tools [
    MarketMySpec.McpServers.Marketing.Tools.ReadFile,
    MarketMySpec.McpServers.Marketing.Tools.WriteFile,
    MarketMySpec.McpServers.Marketing.Tools.ListFiles,
    MarketMySpec.McpServers.Marketing.Tools.EditFile,
    MarketMySpec.McpServers.Engagements.Tools.SearchEngagements,
    MarketMySpec.McpServers.Engagements.Tools.RunSearch,
    MarketMySpec.McpServers.Engagements.Tools.StageResponse,
    MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints,
    MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint,
    MarketMySpec.McpServers.Engagements.Tools.ListVenues,
    MarketMySpec.McpServers.Engagements.Tools.ListSearches
  ]

  @impl MarketMySpec.Chat.ToolRegistry
  @spec list_tools(Conversation.t()) :: [ReqLLM.Tool.t()]
  def list_tools(%Conversation{} = conversation) do
    conversation
    |> tool_modules()
    |> Enum.map(&build_tool(&1, conversation))
  end

  defp tool_modules(%Conversation{type: :problem_discovery}), do: @problem_discovery_tools
  defp tool_modules(%Conversation{type: :marketing_strategy}), do: @marketing_tools
  defp tool_modules(_conversation), do: []

  defp build_tool(module, conversation) do
    name = tool_name(module)

    {:ok, tool} =
      ReqLLM.Tool.new(
        name: name,
        description: description(module, name),
        parameter_schema: module.input_schema(),
        callback: fn args -> dispatch(module, args, conversation) end
      )

    tool
  end

  # Anubis tool components don't expose a name/0 unless given an explicit :name
  # option; the MCP-facing name is the snake_case of the module's last segment
  # (e.g. ListFrames -> "list_frames").
  defp tool_name(module) do
    module |> Module.split() |> List.last() |> Macro.underscore()
  end

  defp description(module, name) do
    case module.__description__() do
      desc when is_binary(desc) and desc != "" -> desc
      _ -> name
    end
  end

  defp dispatch(module, args, conversation) do
    frame = %Frame{assigns: %{current_scope: scope(conversation)}}

    case module.execute(atomize(args), frame) do
      {:reply, response, _frame} -> {:ok, normalize(response)}
      {:error, reason} -> {:error, to_string_reason(reason)}
    end
  end

  defp scope(%Conversation{account_id: account_id}) do
    %Scope{active_account_id: account_id}
  end

  # ReqLLM hands the callback string-keyed args; Anubis components pattern-match
  # atom keys. The keys are the component's declared schema fields, so the atoms
  # already exist.
  defp atomize(args) when is_map(args) do
    Map.new(args, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp normalize(%{content: content}) when is_list(content) do
    content
    |> Enum.map(&content_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp normalize(other), do: inspect(other)

  defp content_text(%{"text" => text}) when is_binary(text), do: text
  defp content_text(%{text: text}) when is_binary(text), do: text
  defp content_text(_), do: ""

  defp to_string_reason(reason) when is_binary(reason), do: reason
  defp to_string_reason(reason), do: inspect(reason)
end
