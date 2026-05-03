defmodule MarketMySpecSpex.Story679.Criterion5790Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5790 — Attempting to grant access for an already-granted agency-client pair is rejected

  Story rule: at most one access grant exists per agency-client pair.
  Submitting a second grant returns a conflict error and only the
  original grant remains.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "duplicate grant for an already-granted agency-client pair is rejected" do
    scenario "the second grant submission returns a conflict error in the form", context do
      given_ "an existing invited grant between an agency and a client", context do
        agency_owner = Fixtures.user_fixture()
        client_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        client_account = Fixtures.account_fixture(client_owner, %{name: "Dup Grant Client"})
        Fixtures.invited_grant_fixture(agency, client_account, access_level: "read_only")
        {token, _raw} = Fixtures.generate_user_magic_link_token(client_owner)

        {:ok,
         Map.merge(context, %{
           client_owner: client_owner,
           token: token,
           agency: agency,
           client_account: client_account
         })}
      end

      when_ "the client owner signs in and tries to grant the same agency a second time", context do
        client_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(client_conn, ~p"/accounts")

        result =
          view
          |> form("[data-test='grant-agency-access-form']",
            grant: %{agency_slug: context.agency.slug, access_level: "account_manager"}
          )
          |> render_submit()

        {:ok, Map.put(context, :second_grant_result, result)}
      end

      then_ "the form re-renders with a uniqueness/conflict error", context do
        assert is_binary(context.second_grant_result),
               "expected the form to re-render on conflict (binary), got: #{inspect(context.second_grant_result)}"

        assert context.second_grant_result =~
                 ~r/already (granted|exists)|duplicate|conflict|already has access/i,
               "expected a conflict error in the form re-render"

        :ok
      end
    end
  end
end
