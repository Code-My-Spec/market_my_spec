defmodule MarketMySpecSpex.Story679.Criterion5782Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5782 — Individual account user cannot access the agency dashboard

  Story rule: a user whose active account is individual cannot reach
  /agency. They receive a 403 or are redirected away; the dashboard is
  not rendered.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "individual account user cannot access the agency dashboard" do
    scenario "/agency is not reachable for a user whose active account is individual" do
      given_ "a registered user with an individual account", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "/agency redirects away rather than rendering the dashboard", context do
        result = live(context.conn, "/agency")

        case result do
          {:error, {:live_redirect, %{to: to}}} ->
            refute to == "/agency"
            assert to =~ ~r/^\/(accounts|$)/, "expected redirect to /accounts or /, got #{to}"

          {:error, {:redirect, %{to: to}}} ->
            refute to == "/agency"
            assert to =~ ~r/^\/(accounts|$)/, "expected redirect to /accounts or /, got #{to}"

          {:ok, _view, _html} ->
            flunk("expected /agency to redirect for an individual-account user, got a render")
        end

        {:ok, context}
      end
    end
  end
end
