defmodule MarketMySpecSpex.Story633.Criterion5671Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5671 — Page passes the messaging-guide phrase audit
  """

  use MarketMySpecSpex.Case

  spex "page passes the messaging-guide phrase audit" do
    scenario "the rendered page contains no banned phrases and includes the canonical positioning line", context do
      given_ "the landing page", context do
        {:ok, context}
      end

      when_ "the page is rendered for an anonymous visitor", context do
        {:ok, _view, html} = live(context.conn, "/")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page does not contain the banned phrase '10x'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/\b10x\b/i
        :ok
      end

      then_ "the page does not contain the banned phrase 'go viral'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/go viral/i
        :ok
      end

      then_ "the page does not contain the banned phrase 'AI-powered marketing'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/AI-powered marketing/i
        :ok
      end

      then_ "the page does not contain the banned phrase 'next-gen'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/next-gen/i
        :ok
      end

      then_ "the page does not contain the banned phrase 'revolutionize'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/revolutionize/i
        :ok
      end

      then_ "the page does not contain the banned phrase 'Lights out software factory'", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/lights out software factory/i
        :ok
      end

      then_ "the page does not contain 'Elixir-first' positioning", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/Elixir-first/i
        :ok
      end

      then_ "the page does not contain 'specification-driven' framing", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/specification-driven/i
        :ok
      end

      then_ "the canonical positioning line is present", context do
        assert context.html =~ "Marketing for founders, in Claude Code"
        :ok
      end
    end
  end
end
