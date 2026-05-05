defmodule MarketMySpecWeb.Journeys.Journey5GrantRevokeTest do
  @moduledoc """
  Journey 5 — Client owner grants agency access; agency revokes the invited grant.

  Covers story 679 criteria 5785, 5786, 5790.

  Steps:
    1. Client owner signs in — sees grant-agency-access-form on /accounts.
    2. Pre-seeded invited grant exists (client→agency direction, as if client submitted the form).
    3. Agency owner signs in, navigates /agency, sees client-row-invited.
    4. Agency clicks the revoke button (opens the confirm modal), then clicks the modal confirm.
    5. Client disappears from agency dashboard.

  The grant is pre-seeded via fixture to obtain the grant.id for targeting the
  modal confirm button (data-test='revoke-grant-modal-<id>-confirm'). Driving
  the grant form itself is covered by story 679 criterion 5785 spex.

  The confirm modal uses a native <dialog> element opened via showModal(). Wallaby
  clicks the revoke button (triggering showModal()), then clicks the confirm button.

  REQUIRES ChromeDriver: `brew install chromedriver`
  Run with: `mix test --include wallaby`
  """

  use MarketMySpecWeb.FeatureCase, async: false

  # Two sessions: one for the client browser, one for the agency browser.
  @sessions 2

  @moduletag :wallaby

  import Wallaby.Query

  feature "client sees grant form; agency revokes invited grant via confirm modal", %{
    sessions: [client_session, agency_session]
  } do
    # Arrange: two users — a client owner (individual account) and an agency owner.
    client_owner = user_fixture()
    client_account = account_fixture(client_owner, %{name: "Client Corp"})
    {client_token, _raw} = generate_user_magic_link_token(client_owner)

    agency_owner = user_fixture()
    agency = agency_account_fixture(agency_owner)
    {agency_token, _raw} = generate_user_magic_link_token(agency_owner)

    # Pre-seed the invited grant (originator: client → agency direction).
    grant = invited_grant_fixture(agency, client_account)

    # Step 1: Client owner signs in and sees the grant form on /accounts.
    client_session
    |> visit("/users/log-in/#{client_token}")
    |> click(css("button[type='submit']"))

    client_session
    |> visit("/accounts")
    |> assert_has(css("[data-test='grant-agency-access-form']"))

    # Step 3: Agency owner signs in, navigates /agency, sees the invited client row.
    agency_session
    |> visit("/users/log-in/#{agency_token}")
    |> click(css("button[type='submit']"))

    agency_session
    |> visit("/agency")
    |> assert_has(css("[data-test='client-row-invited']"))

    # Step 4: Click the Revoke button (opens the confirm modal via showModal()),
    # then click the modal's confirm button to fire the revoke_grant phx event.
    agency_session
    |> click(css("[data-test='revoke-grant']"))
    |> click(css("[data-test='revoke-grant-modal-#{grant.id}-confirm']"))

    # Step 5: Dashboard re-renders — invited client row no longer present.
    agency_session
    |> visit("/agency")
    |> refute_has(css("[data-test='client-row-invited']"))
  end
end
