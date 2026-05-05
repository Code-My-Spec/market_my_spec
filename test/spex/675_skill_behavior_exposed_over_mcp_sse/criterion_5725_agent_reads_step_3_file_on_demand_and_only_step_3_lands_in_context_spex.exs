defmodule MarketMySpecSpex.Story675.Criterion5725Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5725 — Agent reads step 3 file on demand and only step 3 lands in context

  The Step resource must return exactly the content of the requested step
  file — no more, no less. This test calls Step.read/2 directly with the
  step 3 slug and asserts the returned content matches the on-disk file
  and does not contain SKILL.md step-list cross-contamination.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Resources.Step

  @skill_root "priv/skills/marketing-strategy"

  spex "agent reads step 3 file on demand and only step 3 content is returned" do
    scenario "Step.read for step 3 returns exactly the step 3 file content" do
      given_ "the canonical step 3 on-disk content", context do
        step3_content =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("steps/03_persona_research.md")
          |> File.read!()

        frame = %Frame{assigns: %{}}
        {:ok, Map.merge(context, %{step3_content: step3_content, frame: frame})}
      end

      when_ "the agent requests step 3 via Step.read", context do
        result =
          Step.read(
            %{"params" => %{"slug" => "03_persona_research"}},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is successful", context do
        assert match?({:reply, _, _}, context.result),
               "expected {:reply, _, _}, got: #{inspect(context.result)}"

        {:ok, context}
      end

      then_ "the response contains the step 3 file content", context do
        {:reply, response, _frame} = context.result
        text = resource_response_text(response)
        assert text == context.step3_content,
               "expected response to exactly match the on-disk step 3 content"

        {:ok, context}
      end

      then_ "the response does not include SKILL.md step-list content from other files", context do
        {:reply, response, _frame} = context.result
        text = resource_response_text(response)
        assert text =~ ~r/persona|research/i,
               "expected step 3 content to reference persona/research"

        refute text =~ "steps/01_current_state.md",
               "step 3 response must not contain SKILL.md step-list cross-contamination"

        {:ok, context}
      end
    end
  end

  # Resource responses have contents: %{"text" => ...}
  defp resource_response_text(%{contents: %{"text" => text}}), do: text
  defp resource_response_text(%{contents: %{text: text}}), do: text
  defp resource_response_text(other), do: inspect(other)
end
