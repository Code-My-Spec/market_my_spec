defmodule MarketMySpecSpex.Story691.Criterion6018Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6018 — Owner submits a malformed logo URL

  Story rule: the logo URL must be a valid URL. A non-URL string
  ("not-a-url") is rejected with a URL format error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits a malformed logo URL" do
    scenario "a non-URL string is rejected with a URL format error" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits a malformed logo URL", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='branding-form']", branding: %{logo_url: "not-a-url"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with a URL format error and does not save the value", context do
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/invalid url|must be a valid url|url format/i,
               "expected a URL-format error in the rendered form"

        {:ok, _view, html} = live(context.conn, "/agency/settings")

        refute html =~ ~r/value=['"]not-a-url['"]/,
               "expected the malformed URL to NOT be persisted as the prefilled value"

        {:ok, context}
      end
    end
  end
end
