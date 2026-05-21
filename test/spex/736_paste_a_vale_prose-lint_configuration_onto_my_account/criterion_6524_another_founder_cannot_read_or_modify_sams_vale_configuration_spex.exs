defmodule MarketMySpecSpex.Story736.Criterion6524Spex do
  @moduledoc """
  Story 736 — Paste a Vale prose-lint configuration onto my account
  Criterion 6524 — Another founder cannot read or modify Sam's Vale
  configuration.

  Sam has a saved .vale.ini on his Account. Another founder (Bea) logs in
  and attempts to visit Sam's account's style-guide URL. Bea is denied
  access — neither the body nor the form is rendered for her, and her
  attempt cannot mutate Sam's configuration (a fresh mount by Sam shows
  the original body untouched).

  Interaction surface: LiveView (founder-facing web).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @sams_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = Vale
  """

  spex "cross-account access is denied and cannot mutate the other account's configuration" do
    scenario "Sam saves config → Bea visits Sam's URL → denied; Sam's body unchanged" do
      given_ "Sam has saved a .vale.ini and Bea is a separate founder", context do
        sam = Fixtures.user_fixture()
        sam_account = Fixtures.account_fixture(sam)
        {sam_token, _} = Fixtures.generate_user_magic_link_token(sam)

        sam_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => sam_token}})

        {:ok, sam_view, _} = live(sam_conn, "/accounts/#{sam_account.id}/style-guide")

        sam_view
        |> form("[data-test='style-guide-form']", style_guide: %{vale_ini: @sams_vale_ini})
        |> render_submit()

        bea = Fixtures.user_fixture()
        _bea_account = Fixtures.account_fixture(bea)
        {bea_token, _} = Fixtures.generate_user_magic_link_token(bea)

        bea_conn =
          Phoenix.ConnTest.build_conn()
          |> post("/users/log-in", %{"user" => %{"token" => bea_token}})

        {:ok,
         Map.merge(context, %{
           sam_conn: sam_conn,
           sam_account: sam_account,
           bea_conn: bea_conn
         })}
      end

      when_ "Bea attempts to visit Sam's style-guide URL", context do
        bea_mount_result =
          live(context.bea_conn, "/accounts/#{context.sam_account.id}/style-guide")

        {:ok, _sam_view, sam_fresh_html} =
          live(context.sam_conn, "/accounts/#{context.sam_account.id}/style-guide")

        {:ok,
         Map.merge(context, %{
           bea_mount_result: bea_mount_result,
           sam_fresh_html: sam_fresh_html
         })}
      end

      then_ "Bea is denied and Sam's saved body is unchanged", context do
        case context.bea_mount_result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, _view, html} ->
            refute html =~ "StylesPath = /app/priv/vale/styles",
                   "expected Bea NOT to see Sam's .vale.ini body if mount somehow succeeds"

          other ->
            flunk("expected cross-account access denial, got: #{inspect(other)}")
        end

        assert context.sam_fresh_html =~ "StylesPath = /app/priv/vale/styles",
               "expected Sam's saved .vale.ini body unchanged after Bea's attempt"

        assert context.sam_fresh_html =~ "BasedOnStyles = Vale",
               "expected Sam's BasedOnStyles line unchanged after Bea's attempt"

        {:ok, context}
      end
    end
  end
end
