defmodule MarketMySpecSpex.Story633.Criterion5672Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5672 — Draft with banned phrase or enterprise framing is rejected

  Quality gate: any copy containing a banned phrase or enterprise framing fails
  the messaging audit. This spec ensures those signals are absent from the deployed page.
  """

  use MarketMySpecSpex.Case

  spex "banned-phrase quality gate" do
    scenario "the deployed page contains none of the prohibited marketing phrases", context do
      given_ "the landing page at its canonical route", context do
        {:ok, context}
      end

      when_ "the page is rendered", context do
        {:ok, _view, html} = live(context.conn, "/")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "no growth-hack clichés are present", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/\b10x\b/i
        refute context.html =~ ~r/go viral/i
        refute context.html =~ ~r/AI-powered marketing/i
        refute context.html =~ ~r/next-gen/i
        refute context.html =~ ~r/revolutionize/i
        :ok
      end

      then_ "no internal or niche-tech jargon from the banned list is present", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/lights out software factory/i
        refute context.html =~ ~r/Elixir-first/i
        refute context.html =~ ~r/specification-driven/i
        :ok
      end

      then_ "no enterprise framing is present on the primary surface", context do
        assert context.html =~ "Marketing for founders"
        refute context.html =~ ~r/enterprise/i
        :ok
      end
    end
  end
end
