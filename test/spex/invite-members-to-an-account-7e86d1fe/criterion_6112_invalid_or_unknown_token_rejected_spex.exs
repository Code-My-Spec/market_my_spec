defmodule MarketMySpecSpex.Story696.Criterion6112Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6112 — Invalid or unknown token rejected

  When a visitor navigates to the accept URL with a token that does not
  correspond to any invitation in the database, the page renders an
  "Invalid Invitation" error message.
  """

  use MarketMySpecSpex.Case

  spex "invalid or unknown token rejected", fail_on_error_logs: false do
    scenario "visitor uses a bogus token and sees an invalid invitation error" do
      given_ "no matching invitation exists in the system", context do
        {:ok, context}
      end

      when_ "visitor navigates to the accept URL with a random token", context do
        {:ok, view, _html} = live(context.conn, "/invitations/accept/totallybogustoken123")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an Invalid Invitation error", context do
        html = render(context.view)

        assert html =~ "Invalid Invitation" or
                 html =~ "invalid or has been cancelled" or
                 html =~ "invalid",
               "expected an error message for an unknown token"

        {:ok, context}
      end
    end
  end
end
