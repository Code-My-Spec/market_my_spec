defmodule MarketMySpecSpex.Story634.Criterion5706Spex do
  @moduledoc """
  Story 634 — MCP Setup Guide
  Criterion 5706 — Page lacking expected-result verification step is rejected

  Quality gate: each step in the setup guide must have an expected-result block
  so the user can verify their setup succeeded. A guide without this element fails.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "expected-result verification step quality gate" do
    scenario "the deployed guide contains an expected-result verification element" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they visit the MCP setup guide", context do
        {:ok, view, _html} = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "an expected-result verification element is present", context do
        assert has_element?(context.view, "[data-test='expected-result']")
        {:ok, context}
      end

      then_ "the expected-result element contains meaningful verification content", context do
        result_html = context.view |> element("[data-test='expected-result']") |> render()
        assert result_html =~ ~r/(connected|success|working|installed)/i
        refute result_html =~ ~r/^\s*$/
        {:ok, context}
      end
    end
  end
end
