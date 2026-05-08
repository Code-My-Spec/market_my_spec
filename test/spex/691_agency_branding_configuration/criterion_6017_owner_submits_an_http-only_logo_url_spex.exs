defmodule MarketMySpecSpex.Story691.Criterion6017Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6017 — Owner submits an HTTP-only logo URL

  Story rule: the logo URL must be HTTPS. A bare `http://` URL is
  rejected with a "must be HTTPS" (or equivalent) error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits an HTTP-only logo URL" do
    scenario "an http:// URL is rejected with an HTTPS-required error" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits an http-only logo URL", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='branding-form']",
            branding: %{logo_url: "http://acme.example/logo.svg"}
          )
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with an HTTPS-required error and does not save the URL", context do
        # render_submit returns binary HTML on validation failure (no
        # redirect tuple). A redirect here would mean the URL was saved.
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/must be https|requires https|http(s)? required/i,
               "expected an HTTPS-required error in the rendered form"

        # Reload the form independently and confirm the bad URL was not
        # persisted.
        {:ok, _view, html} = live(context.conn, "/agency/settings")

        refute html =~ "http://acme.example/logo.svg",
               "expected the http-only URL to NOT be persisted"

        {:ok, context}
      end
    end
  end
end
