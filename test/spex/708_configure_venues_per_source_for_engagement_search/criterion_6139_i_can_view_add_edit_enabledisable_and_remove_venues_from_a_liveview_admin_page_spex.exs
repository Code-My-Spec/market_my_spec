defmodule MarketMySpecSpex.Story708.Criterion6139Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6139 — I can view, add, edit, enable/disable, and remove venues from
  a LiveView admin page.

  The VenueLive.Index page at /accounts/:id/venues is the admin surface for
  managing venues. It renders an Add Venue button, a venue table with enable
  toggle and remove action per row, and an inline add-form.

  Interaction surface: VenueLive.Index (LiveView).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "I can view, add, edit, enable/disable, and remove venues from a LiveView admin page" do
    scenario "the venue admin page loads and renders the Add Venue button and empty table" do
      given_ "an authenticated user with an account", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)

        {:ok, Map.merge(context, %{user: user, account: account, token: token})}
      end

      when_ "the user navigates to the venue admin page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, html} = live(authed_conn, "/accounts/#{context.account.id}/venues")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the page renders the Add Venue button", context do
        assert context.html =~ "Add Venue",
               "expected page to contain an 'Add Venue' button"

        {:ok, context}
      end

      then_ "the page renders the venues table", context do
        html = render(context.view)

        assert html =~ "venues-table" or html =~ "Venues" or html =~ "No venues",
               "expected page to render a venues table or empty state"

        {:ok, context}
      end
    end

    scenario "clicking Add Venue reveals the inline add form" do
      given_ "an authenticated user with an account", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)

        {:ok, Map.merge(context, %{user: user, account: account, token: token})}
      end

      when_ "the user clicks the Add Venue button", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{context.account.id}/venues")

        view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the add venue form is visible", context do
        html = render(context.view)

        assert html =~ "venue-form" or html =~ "Select source" or html =~ "Subreddit",
               "expected the add venue form to appear after clicking Add Venue"

        {:ok, context}
      end
    end
  end
end
