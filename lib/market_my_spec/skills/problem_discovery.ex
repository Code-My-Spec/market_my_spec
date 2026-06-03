defmodule MarketMySpec.Skills.ProblemDiscovery do
  @moduledoc """
  Problem-discovery skill — file-backed under `priv/skills/problem-discovery/`.

  Guides the agent through the 5-stage discovery pipeline (Frame → Gather →
  Cluster → Score → Red-team → Board), invoking the ProblemDiscovery MCP
  tools at each stage. Per-phase guidance lives in `steps/NN_*.md`;
  practitioner research grounding each phase lives in `research/*.md`. Both
  are loaded lazily by the agent via progressive disclosure — the agent
  starts with SKILL.md and reads deeper files as it enters each phase.

  Mirrors the file-backed-reader pattern of
  `MarketMySpec.Skills.MarketingStrategy` exactly, including path-traversal
  protection on `read_skill_file/1`.

  See `architecture/decisions/problem-discovery-skill.md` for the why.
  """

  @skill_name "problem-discovery"

  @doc """
  The skill name as exposed via MCP.
  """
  @spec name() :: String.t()
  def name, do: @skill_name

  @doc """
  Absolute path to the skill's root directory under `priv/`.
  """
  @spec root_dir() :: String.t()
  def root_dir do
    Application.app_dir(:market_my_spec, "priv/skills/#{@skill_name}")
  end

  @doc """
  Read the SKILL.md body — the orientation document loaded by `invoke_skill`.
  """
  @spec read_skill_md() :: {:ok, String.t()} | {:error, File.posix()}
  def read_skill_md do
    root_dir()
    |> Path.join("SKILL.md")
    |> File.read()
  end

  @doc """
  Read a file inside the skill by relative path (e.g. `"steps/01_frame.md"`
  or `"research/04_clustering_qualitative_records.md"`).

  Path-traversal attempts (`..`, absolute paths, paths that resolve outside
  the skill root) return `{:error, :unsafe_path}` before any filesystem
  read. Files that don't exist return `{:error, :enoent}`.
  """
  @spec read_skill_file(String.t()) ::
          {:ok, String.t()} | {:error, :unsafe_path | File.posix()}
  def read_skill_file(relative_path) when is_binary(relative_path) do
    with {:ok, safe_relative} <- safe_relative(relative_path),
         absolute = Path.join(root_dir(), safe_relative),
         {:ok, resolved} <- ensure_inside_root(absolute) do
      File.read(resolved)
    end
  end

  defp safe_relative(path) do
    case Path.safe_relative(path) do
      {:ok, safe} -> {:ok, safe}
      :error -> {:error, :unsafe_path}
    end
  end

  defp ensure_inside_root(absolute) do
    expanded = Path.expand(absolute)
    root = Path.expand(root_dir())

    case String.starts_with?(expanded, root <> "/") or expanded == root do
      true -> {:ok, expanded}
      false -> {:error, :unsafe_path}
    end
  end
end
