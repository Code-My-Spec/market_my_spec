defmodule MarketMySpec.Skills do
  @moduledoc """
  Public boundary for the marketing-strategy skill.

  Delegates landing-page copy to `MarketMySpec.Skills.Overview` and
  skill-file access to `MarketMySpec.Skills.MarketingStrategy`.

  All functions are pure data lookups — no I/O except the file-read
  functions, which delegate directly to the underlying module.
  """

  alias MarketMySpec.Skills.MarketingStrategy
  alias MarketMySpec.Skills.Overview

  # ---------------------------------------------------------------------------
  # Landing-page copy (delegates to Overview)
  # ---------------------------------------------------------------------------

  @doc """
  The headline for the marketing-strategy skill landing page.
  """
  @spec headline() :: String.t()
  defdelegate headline(), to: Overview

  @doc """
  A one-sentence value proposition for the skill.
  """
  @spec value_proposition() :: String.t()
  defdelegate value_proposition(), to: Overview

  @doc """
  The BYO-Claude notice — map with `:title` and `:description`.
  """
  @spec byo_claude_notice() :: %{title: String.t(), description: String.t()}
  defdelegate byo_claude_notice(), to: Overview

  @doc """
  Audience description for the skill landing page.
  """
  @spec target_audience() :: String.t()
  defdelegate target_audience(), to: Overview

  @doc """
  The feature cards shown on the landing page.
  """
  @spec features() :: [Overview.feature()]
  defdelegate features(), to: Overview

  # ---------------------------------------------------------------------------
  # Skill file access (delegates to MarketingStrategy)
  # ---------------------------------------------------------------------------

  @doc """
  The skill name as exposed via MCP.
  """
  @spec skill_name() :: String.t()
  def skill_name, do: MarketingStrategy.name()

  @doc """
  Read the SKILL.md orientation document.
  """
  @spec read_skill_md() :: {:ok, String.t()} | {:error, File.posix()}
  defdelegate read_skill_md(), to: MarketingStrategy

  @doc """
  Read a file inside the skill by relative path.

  Path-traversal attempts and out-of-root paths return `{:error, :unsafe_path}`.
  """
  @spec read_skill_file(String.t()) ::
          {:ok, String.t()} | {:error, :unsafe_path | File.posix()}
  defdelegate read_skill_file(relative_path), to: MarketingStrategy
end
