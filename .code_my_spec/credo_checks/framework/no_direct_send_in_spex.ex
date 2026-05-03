defmodule CodeMySpec.Check.Warning.NoDirectSendInSpex do
  use Credo.Check,
    id: "CMS0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Direct `send()` calls should not be used in BDD spec files (`_spex.exs`).

      Specs describe behavior from the user's perspective. Sending messages directly
      to a process bypasses the application's public interface and couples the spec
      to implementation details.

      Instead, trigger the behavior through the UI or public API that would cause
      the message to be sent in production.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if String.ends_with?(filename, "_spex.exs") do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    else
      []
    end
  end

  # send(pid, message)
  defp walk({:send, meta, [_, _]} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "send"))}
  end

  # Kernel.send(pid, message)
  defp walk({{:., _, [{:__aliases__, meta, [:Kernel]}, :send]}, _, [_, _]} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "Kernel.send"))}
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp issue_for(issue_meta, meta, trigger) do
    format_issue(
      issue_meta,
      message: "Direct `send()` is not allowed in _spex.exs files. Trigger behavior through the UI or public API instead.",
      trigger: trigger,
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
