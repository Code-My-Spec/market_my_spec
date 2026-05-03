defmodule MarketMySpecSpex.Story673.Criterion5686Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5686 — User cancels GitHub authorization and recovers cleanly
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "user cancels GitHub authorization and recovers cleanly" do
    scenario "user who cancels GitHub authorization sees a clear error and can try again" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "GitHub returns an access_denied callback", context do
        conn = get(context.conn, "/integrations/oauth/callback/github?error=access_denied")
        {:ok, Map.put(context, :callback_conn, conn)}
      end

      then_ "the user is redirected away from the callback", context do
        assert redirected_to(context.callback_conn, 302) =~ "/integrations"
        {:ok, context}
      end

      then_ "an error flash message is shown explaining the cancellation", context do
        error_flash = get_flash(context.callback_conn, :error)
        assert error_flash, "expected an error flash to be set"
        assert error_flash =~ ~r/denied|access/i
        {:ok, context}
      end
    end
  end
end
