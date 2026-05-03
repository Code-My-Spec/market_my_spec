defmodule MarketMySpecSpex.Story678.Criterion5774Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5774 — Duplicate slug is rejected at creation

  Story rule: account slugs are globally unique. A second account whose
  derived slug collides with an existing slug surfaces a uniqueness
  error and is not created.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "duplicate slug is rejected at creation" do
    scenario "second account form submission with a colliding slug renders a uniqueness error", context do
      given_ "two registered users (so each can create an account independently)", context do
        owner_a = Fixtures.user_fixture()
        owner_b = Fixtures.user_fixture()
        {token_a, _raw} = Fixtures.generate_user_magic_link_token(owner_a)
        {token_b, _raw} = Fixtures.generate_user_magic_link_token(owner_b)
        {:ok, Map.merge(context, %{owner_a: owner_a, owner_b: owner_b, token_a: token_a, token_b: token_b})}
      end

      when_ "owner A signs in and creates 'Slug Test Workspace'", context do
        conn_a = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token_a}})
        {:ok, view, _html} = live(conn_a, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Slug Test Workspace"})
        |> render_submit()

        {:ok, Map.put(context, :conn_a, conn_a)}
      end

      when_ "owner B signs in and submits a form whose name produces the same slug", context do
        conn_b =
          Phoenix.ConnTest.build_conn()
          |> post("/users/log-in", %{"user" => %{"token" => context.token_b}})

        {:ok, view, _html} = live(conn_b, "/accounts/new")

        result =
          view
          |> form("[data-test='account-form']", account: %{name: "Slug Test Workspace"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn_b: conn_b, second_form_result: result})}
      end

      then_ "the second submission re-renders the form with a uniqueness error", context do
        # On validation failure render_submit returns the rendered HTML
        # (a binary), not a redirect. A redirect tuple here would mean
        # silent success.
        assert is_binary(context.second_form_result),
               "expected form submit to re-render the form (binary), got: #{inspect(context.second_form_result)}"

        assert context.second_form_result =~ ~r/already (taken|exists)|not unique|must be unique/i,
               "expected a uniqueness error in the rendered form"

        :ok
      end
    end
  end
end
