defmodule MarketMySpecSpex.Story731.Criterion6473Spex do
  @moduledoc """
  Story 731 — 6473. Anonymous user is challenged to sign in before pairing.
  Surface: /agents/pair redirect when no session.
  """
  use MarketMySpecSpex.Case

  spex "anonymous user is challenged to sign in before pairing" do
    scenario "unauthenticated visit redirects to sign-in" do
      when_ "an anonymous browser opens /agents/pair", context do
        result = live(context.conn, "/agents/pair?state=ABC&port=51234&name=mac-mini")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is a redirect to the sign-in page", context do
        assert {:error, {:redirect, %{to: to}}} = context.result
        assert to =~ "/users/log-in"
        {:ok, context}
      end
    end
  end
end
