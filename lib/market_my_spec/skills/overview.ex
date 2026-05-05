defmodule MarketMySpec.Skills.Overview do
  @moduledoc """
  Public marketing copy for the marketing-strategy skill.

  Provides value proposition, BYO-Claude requirement notice, and target
  audience description consumed by HomeLive to render the public landing page.

  All functions return pure, static data — no I/O, no side effects.
  """

  @type feature :: %{title: String.t(), description: String.t()}

  @doc """
  The headline that communicates the primary value of the skill.
  """
  @spec headline() :: String.t()
  def headline, do: "Marketing strategy your agent runs."

  @doc """
  A one-sentence description of what the skill delivers.
  """
  @spec value_proposition() :: String.t()
  def value_proposition do
    "Market My Spec gives your Claude Code agent a marketing-strategy skill over MCP. " <>
      "Skip the strategy consultant — bring your own Claude and walk through eight steps " <>
      "with an AI that knows your product."
  end

  @doc """
  The BYO-Claude requirement statement for display below the hero.

  Returns a map with `:title` and `:description` keys so callers can
  render them independently (heading vs. body copy).
  """
  @spec byo_claude_notice() :: %{title: String.t(), description: String.t()}
  def byo_claude_notice do
    %{
      title: "Bring your own Claude",
      description:
        "No token markup. Connect your own Claude Code subscription. We never resell tokens."
    }
  end

  @doc """
  Audience description — who this skill is for.
  """
  @spec target_audience() :: String.t()
  def target_audience, do: "Built for AI-native solo founders"

  @doc """
  The three feature cards shown on the landing page.

  Returns a list of maps with `:title` and `:description` keys in display order.
  """
  @spec features() :: [feature()]
  def features do
    [
      %{
        title: "Bring your own Claude",
        description:
          "No token markup. Connect your own Claude Code subscription. We never resell tokens."
      },
      %{
        title: "Eight-step strategy",
        description:
          "ICP, positioning, channels, content. Your agent walks the steps, " <>
            "saves artifacts, and you review."
      },
      %{
        title: "Lives in your editor",
        description:
          "Skills load over MCP. No new app to learn — your agent already knows how to use it."
      }
    ]
  end
end
