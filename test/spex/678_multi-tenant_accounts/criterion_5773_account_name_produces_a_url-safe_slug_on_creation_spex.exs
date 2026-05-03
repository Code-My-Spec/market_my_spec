defmodule MarketMySpecSpex.Story678.Criterion5773Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5773 — Account name produces a URL-safe slug on creation
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "account name produces a URL-safe slug on creation" do
    scenario "creating an account with a mixed-case spaced name yields a lowercase hyphenated slug visible in the UI" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user creates an account named 'My Marketing Workspace'", context do
        {:ok, view, _html} = live(context.conn, "/accounts/new")

        result =
          view
          |> form("[data-test='account-form']", account: %{name: "My Marketing Workspace"})
          |> render_submit()

        {:ok, Map.put(context, :create_result, result)}
      end

      then_ "the accounts list shows the new account with a URL-safe slug rendering", context do
        accounts_html =
          case live(context.conn, "/accounts") do
            {:ok, _view, html} -> html
            _ -> ""
          end

        assert accounts_html != "", "expected accounts list to render after slug creation"
        assert accounts_html =~ ~r/My Marketing Workspace/i,
               "expected the new account name to be visible"

        assert accounts_html =~ ~r/my-marketing-workspace/,
               "expected URL-safe lowercase-hyphenated slug 'my-marketing-workspace'"

        {:ok, context}
      end

      then_ "the rendered slug contains no uppercase or whitespace characters", context do
        accounts_html =
          case live(context.conn, "/accounts") do
            {:ok, _view, html} -> html
            _ -> ""
          end

        assert accounts_html != "", "anchor: expected accounts list to render"

        refute accounts_html =~ ~r/My-Marketing-Workspace/,
               "expected slug not to preserve original capitalization"

        refute accounts_html =~ ~r/my marketing workspace/,
               "expected slug not to preserve whitespace"

        {:ok, context}
      end
    end
  end
end
