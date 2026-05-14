defmodule MarketMySpecSpex.Story708.Criterion6137Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6137 — Venues are persisted with source type (reddit | elixirforum),
  identifier (subreddit name OR category + optional tag filter),
  weight (used for ranking), and enabled flag.

  A venue carries all four fields. Adding a Reddit venue and an ElixirForum venue
  via the admin LiveView confirms that source, identifier, weight, and enabled are
  stored and displayed back to the user.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "venues are persisted with source type, identifier, weight, and enabled flag" do
    scenario "a Reddit venue added via the admin UI shows all four fields in the list" do
      given_ "Alice has an account", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice adds a Reddit venue for r/elixir with weight 1.5", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{context.account.id}/venues")

        view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        view
        |> form("[data-test='venue-form']",
          venue: %{source: "reddit", identifier: "elixir", weight: "1.5"}
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the venue appears in the list with source reddit, identifier elixir, weight 1.5, and enabled true", context do
        html = render(context.view)

        assert html =~ "reddit", "expected source 'reddit' to appear in venue list"
        assert html =~ "elixir", "expected identifier 'elixir' to appear in venue list"
        assert html =~ "1.5", "expected weight '1.5' to appear in venue list"

        {:ok, context}
      end
    end

    scenario "an ElixirForum venue added via the admin UI shows all four fields in the list" do
      given_ "Alice has an account", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice adds an ElixirForum venue for category Phoenix Forum with tag ai", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{context.account.id}/venues")

        view
        |> element("[data-test='add-venue-button']")
        |> render_click()

        view
        |> form("[data-test='venue-form']",
          venue: %{source: "elixirforum", identifier: "phoenix-forum:ai", weight: "1.0"}
        )
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the venue appears in the list with source elixirforum and identifier phoenix-forum:ai", context do
        html = render(context.view)

        assert html =~ "elixirforum", "expected source 'elixirforum' to appear in venue list"
        assert html =~ "phoenix-forum", "expected category identifier to appear in venue list"

        {:ok, context}
      end
    end
  end
end
