defmodule MarketMySpec.Skills.MarketingStrategy do
  @moduledoc """
  Marketing-strategy skill — file-backed under `priv/skills/marketing-strategy/`.

  Exposes the SKILL.md orientation and the eight step prompts as raw file
  bodies. MCP tool modules (`invoke_skill`, `read_skill_file`) call into
  this module to serve content to connected agents.

  Source-of-truth is the on-disk file content; this module does not
  synthesize prompts at runtime.
  """

  @skill_name "marketing-strategy"

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
  Read a file inside the skill by relative path (e.g. `"steps/01_current_state.md"`).

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
