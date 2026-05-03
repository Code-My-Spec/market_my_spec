defmodule MarketMySpecSpex.Story678.Criterion5777Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5777 — Self-service account creation always produces an individual account

  Story rule: agency accounts are admin-provisioned only. The
  self-service /accounts/new form has no agency type selector and any
  user-supplied `type=agency` is ignored — the resulting account is
  always individual.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "self-service account creation always produces an individual account" do
    scenario "the new-account form has no agency selector and ignores a smuggled-in type=agency", context do
      given_ "a registered (non-admin) user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user submits the form with name only and again with type=agency smuggled in", context do
        {:ok, view, _html} = live(context.conn, "/accounts/new")

        # The form should not expose an agency type selector at all.
        refute has_element?(view, "[data-test='account-form'] [name='account[type]']"),
               "self-service /accounts/new must not expose an account[type] selector"

        view
        |> form("[data-test='account-form']", account: %{name: "Self Service Test"})
        |> render_submit()

        {:ok, view2, _html2} = live(context.conn, "/accounts/new")

        view2
        |> form("[data-test='account-form']",
          account: %{name: "Agency Sneak Attempt", type: "agency"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "both accounts appear on /accounts marked as individual, never as agency", context do
        {:ok, _view, accounts_html} = live(context.conn, "/accounts")

        assert accounts_html =~ ~r/Self Service Test/,
               "expected the self-service account to be present"

        assert accounts_html =~ ~r/Agency Sneak Attempt/,
               "expected the smuggled-in account name to be present"

        # Each account row should carry an account-type marker; both must say individual.
        [_ | rows] = String.split(accounts_html, "data-test=\"account-row\"")

        types =
          rows
          |> Enum.map(fn row ->
            case Regex.run(~r/data-test="account-type-(individual|agency)"/, row) do
              [_, type] -> type
              _ -> nil
            end
          end)

        assert Enum.all?(types, &(&1 == "individual")),
               "expected every self-service account to be type=individual, got: #{inspect(types)}"

        :ok
      end
    end
  end
end
