defmodule MarketMySpecSpex.Story708.Criterion6155Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6155 — Sam adds a new venue from the admin UI.

  Sam opens the Add Venue form on VenueLive.Index, fills in source, identifier,
  and weight, submits the form, and sees the new venue appear in the list.

  Interaction surface: VenueLive.Index (LiveView).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "Sam adds a new venue from the admin UI" do
    scenario "Sam adds a Reddit venue and it appears in the venue list" do
      given_ "Sam has an account and is on the venue admin page", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{account.id}/venues")

        {:ok, Map.merge(context, %{sam: sam, account: account, view: view})}
      end

      when_ "Sam clicks Add Venue and submits the form with r/elixir", context do
        context.view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        context.view
        |> form("[data-test='venue-form']",
          venue: %{source: "reddit", identifier: "elixir", weight: "1.0"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the venue list shows the new r/elixir venue", context do
        html = render(context.view)

        assert html =~ "elixir",
               "expected 'elixir' to appear in the venue list after adding"

        assert html =~ "reddit",
               "expected 'reddit' source badge to appear in the venue list"

        {:ok, context}
      end
    end

    scenario "Sam adds an ElixirForum venue and it appears in the venue list" do
      given_ "Sam has an account and is on the venue admin page", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{account.id}/venues")

        {:ok, Map.merge(context, %{sam: sam, account: account, view: view})}
      end

      when_ "Sam clicks Add Venue and submits an ElixirForum venue", context do
        context.view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        context.view
        |> form("[data-test='venue-form']",
          venue: %{source: "elixirforum", identifier: "phoenix-forum", weight: "1.0"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the venue list shows the ElixirForum venue", context do
        html = render(context.view)

        assert html =~ "elixirforum",
               "expected 'elixirforum' source to appear in the venue list"

        assert html =~ "phoenix-forum",
               "expected 'phoenix-forum' identifier to appear in the venue list"

        {:ok, context}
      end
    end

    scenario "submitting an invalid subreddit name shows a form error" do
      given_ "Sam has an account and opens the Add Venue form", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{account.id}/venues")

        view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        {:ok, Map.merge(context, %{account: account, view: view})}
      end

      when_ "Sam submits an invalid subreddit name (too short)", context do
        context.view
        |> form("[data-test='venue-form']",
          venue: %{source: "reddit", identifier: "ab", weight: "1.0"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "a validation error message is shown", context do
        html = render(context.view)

        assert html =~ "Invalid" or html =~ "error" or html =~ "venue-form-error",
               "expected a validation error message for an invalid subreddit name"

        {:ok, context}
      end
    end
  end
end
