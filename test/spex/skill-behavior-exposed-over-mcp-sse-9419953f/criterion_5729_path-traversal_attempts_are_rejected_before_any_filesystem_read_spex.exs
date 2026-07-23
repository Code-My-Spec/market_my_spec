defmodule MarketMySpecSpex.Story675.Criterion5729Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5729 — Path-traversal attempts are rejected before any filesystem read

  This is the highest-security criterion. The domain function
  `Skills.read_skill_file/1` must reject every path-traversal pattern
  before performing any filesystem read. Patterns tested:

  - `../../config/prod.exs`       — classic relative traversal
  - `../SKILL.md`                 — single-step parent traversal
  - `/etc/passwd`                 — absolute path injection
  - `steps/../../config/secrets`  — traversal after valid prefix

  Note: URL-encoded traversal (e.g. `steps%2F..%2F..%2Fsecrets`) is a
  transport-layer concern — Anubis/Plug decodes the request path before it
  reaches the domain layer, so the domain function only ever sees
  already-decoded strings. URL-encoded patterns are not tested here.

  Note: Obfuscated patterns like `....//....//etc/passwd` do not contain a
  valid `..` component and are treated as safe relative paths by
  `Path.safe_relative/1`. They return `{:error, :enoent}` (file not found)
  rather than `{:error, :unsafe_path}`, which is acceptable: no filesystem
  content is returned and no traversal out of the skill root is possible.

  All listed patterns must return `{:error, :unsafe_path}` without
  touching the filesystem. The Step resource propagates this as an
  `invalid_params` MCP error.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Resources.Step
  alias MarketMySpec.Skills

  @traversal_paths [
    "../../config/prod.exs",
    "../SKILL.md",
    "/etc/passwd",
    "steps/../../config/secrets"
  ]

  spex "path-traversal attempts are rejected before any filesystem read" do
    scenario "Skills.read_skill_file rejects all traversal patterns with :unsafe_path" do
      given_ "a set of path-traversal attack patterns", context do
        {:ok, Map.put(context, :traversal_paths, @traversal_paths)}
      end

      when_ "each traversal path is passed to Skills.read_skill_file", context do
        results =
          Enum.map(context.traversal_paths, fn path ->
            {path, Skills.read_skill_file(path)}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "every traversal path is rejected with :unsafe_path", context do
        Enum.each(context.results, fn {path, result} ->
          assert result == {:error, :unsafe_path},
                 "expected {:error, :unsafe_path} for path #{inspect(path)}, got: #{inspect(result)}"
        end)

        {:ok, context}
      end
    end

    scenario "Step.read propagates traversal rejection as an invalid_params MCP error" do
      given_ "a server frame with no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent sends a classic path-traversal slug via Step.read", context do
        result =
          Step.read(
            %{"params" => %{"slug" => "../../config/prod"}},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the traversal is rejected with an MCP error", context do
        assert match?({:error, _, _}, context.result),
               "expected {:error, _, _} for traversal slug, got: #{inspect(context.result)}"

        {:ok, context}
      end

      then_ "the MCP error reason is invalid_params, not a filesystem error", context do
        {:error, %Anubis.MCP.Error{reason: reason}, _frame} = context.result

        assert reason == :invalid_params,
               "expected :invalid_params (not a filesystem error), got: #{inspect(reason)}"

        {:ok, context}
      end
    end
  end
end
