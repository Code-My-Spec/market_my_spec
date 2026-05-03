defmodule MarketMySpecSpex.Story678.Criterion5771Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5771 — Two members in the same account see the same MCP connection

  Story rule: all platform data — MCP connections, strategy artifacts,
  settings — belongs to the account, not the individual user. Two
  members of the same account should see the same MCP connection.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "two members in the same account see the same MCP connection" do
    scenario "owner and a second member both see the same MCP server URL on /mcp-setup" do
      given_ "a registered owner user", context do
        owner = Fixtures.user_fixture()
        {owner_token, _raw} = Fixtures.generate_user_magic_link_token(owner)
        {:ok, Map.merge(context, %{owner: owner, owner_token: owner_token})}
      end

      given_ "a registered second user (prospective member)", context do
        member = Fixtures.user_fixture()
        {member_token, _raw} = Fixtures.generate_user_magic_link_token(member)
        {:ok, Map.merge(context, %{member: member, member_token: member_token})}
      end

      when_ "the owner signs in, creates 'Shared MCP Account', and invites the member", context do
        owner_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.owner_token}})

        {:ok, view, _html} = live(owner_conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Shared MCP Account"})
        |> render_submit()

        {:ok, accounts_view, _html} = live(owner_conn, ~p"/accounts")

        accounts_view
        |> form("[data-test='invite-member-form']",
          invitation: %{email: context.member.email, role: "member"}
        )
        |> render_submit()

        {:ok, Map.put(context, :owner_conn, owner_conn)}
      end

      when_ "owner and member each visit /mcp-setup in their own sessions", context do
        {:ok, _owner_view, owner_mcp_html} = live(context.owner_conn, "/mcp-setup")

        member_conn = Phoenix.ConnTest.build_conn()

        member_conn =
          post(member_conn, "/users/log-in", %{"user" => %{"token" => context.member_token}})

        {:ok, _member_view, member_mcp_html} = live(member_conn, "/mcp-setup")

        {:ok,
         Map.merge(context, %{
           member_conn: member_conn,
           owner_mcp_html: owner_mcp_html,
           member_mcp_html: member_mcp_html
         })}
      end

      then_ "both sessions render the same MCP server URL", context do
        # Extract the rendered MCP server URL from each session.
        owner_url =
          context.owner_mcp_html
          |> Floki.parse_document!()
          |> Floki.find("[data-test='server-url']")
          |> Floki.text()
          |> String.trim()

        member_url =
          context.member_mcp_html
          |> Floki.parse_document!()
          |> Floki.find("[data-test='server-url']")
          |> Floki.text()
          |> String.trim()

        assert owner_url != "", "expected owner to see a non-empty MCP server URL"
        assert owner_url == member_url,
               "expected owner and member of the same account to see the same MCP server URL, got owner=#{inspect(owner_url)} member=#{inspect(member_url)}"

        {:ok, context}
      end
    end
  end
end
