defmodule MarketMySpecSpex.Story707.Criterion6404Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6404 — `polished_body` is plain text suitable for direct
  copy-paste into Reddit or ElixirForum — no HTML, no transformations
  beyond platform-native markdown.

  Body in → body out (modulo the link_target → UTM-link substitution).
  No HTML tags, no entity encoding (`&amp;` etc.), no <p>/<br>
  wrapping, no Markdown-to-HTML conversion. The body must be safe to
  paste verbatim into a Reddit comment box.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "polished_body is plain text — no HTML, no encoding, copy-paste safe" do
    scenario "Body with markdown + ampersand + apostrophe stored verbatim, only link_target replaced" do
      given_ "a persisted Reddit Thread", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "txt404",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages a markdown body containing characters HTML would normally escape",
            context do
        link_target = "https://marketmyspec.com/post"

        # Includes markdown bullets, ampersand, apostrophe, angle brackets
        # in prose — all should pass through verbatim.
        polished_body = """
        Here's what I'd do:

        - Drop the spec.
        - Run it & verify.
        - Tag <yourself> in the PR.

        Writeup: #{link_target}
        """

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: polished_body,
              link_target: link_target
            },
            context.frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        touchpoints =
          (decode_payload(list_resp))["touchpoints"] ||
            (decode_payload(list_resp))["list"] || []

        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == touchpoint_id))

        {:ok,
         Map.merge(context, %{
           stored_body: tp && (tp["polished_body"] || tp[:polished_body]),
           original_link: link_target
         })}
      end

      then_ "stored body preserves markdown, ampersand, apostrophe, angle brackets verbatim",
            context do
        assert context.stored_body, "expected stored polished_body"

        # No HTML entity encoding
        refute context.stored_body =~ "&amp;", "ampersand should not be entity-encoded"
        refute context.stored_body =~ "&lt;", "< should not be entity-encoded"
        refute context.stored_body =~ "&gt;", "> should not be entity-encoded"
        refute context.stored_body =~ "&#39;", "apostrophe should not be entity-encoded"
        refute context.stored_body =~ "&quot;", "double-quote should not be entity-encoded"

        # No HTML tag wrapping
        refute context.stored_body =~ "<p>", "no <p> wrapping"
        refute context.stored_body =~ "<br", "no <br> insertion"
        refute context.stored_body =~ "<li>", "no <li> wrapping of bullets"
        refute context.stored_body =~ "<ul>", "no <ul> wrapping of bullets"

        # Markdown bullets/quotes preserved verbatim
        assert context.stored_body =~ "- Drop the spec.", "bullet preserved"
        assert context.stored_body =~ "Run it & verify.", "ampersand preserved verbatim"
        assert context.stored_body =~ "<yourself>", "angle brackets in prose preserved verbatim"
        assert context.stored_body =~ "Here's what", "apostrophe preserved verbatim"

        # Link was substituted (so we know body wasn't byte-for-byte identical,
        # but the substitution is the only transformation)
        refute context.stored_body =~ "https://marketmyspec.com/post\n",
               "expected original link_target replaced by UTM URL (not bare URL)"

        assert context.stored_body =~ "utm_source=reddit",
               "expected UTM substitution applied at link_target position"

        {:ok, context}
      end
    end
  end
end
