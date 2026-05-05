defmodule MarketMySpecWeb.Journeys.Journey4AgencyDashboardTest do
  @moduledoc """
  Journey 4 — Agency owner sets up agency account, creates a client, navigates in/out.

  Covers stories: 679 (Agency Account Type And Client Dashboard), 678 (scope switching).

  Steps:
    1. Agency user signs in — nav shows agency-dashboard link.
    2. Clicks agency dashboard — lands on /agency (empty initially).
    3. Navigates to /agency/clients/new, fills client form, submits.
    4. Dashboard shows client row with data-test='client-row-originator'.
    5. Clicks data-test='enter-client' — scope switches to client.
    6. /accounts shows data-test='inside-client-indicator'.

  REQUIRES ChromeDriver: `brew install chromedriver`
  Run with: `mix test --include wallaby`
  """

  use MarketMySpecWeb.FeatureCase, async: false

  @moduletag :wallaby

  import Wallaby.Query

  feature "agency owner creates client and switches into client scope", %{session: session} do
    # Arrange: admin-provisioned agency account owner.
    agency_owner = user_fixture()
    _agency = agency_account_fixture(agency_owner)
    {encoded_token, _raw} = generate_user_magic_link_token(agency_owner)

    # Sign in as agency owner.
    session
    |> visit("/users/log-in/#{encoded_token}")
    |> click(css("button[type='submit']"))

    # Step 1: Nav shows the agency-dashboard link on /accounts.
    session
    |> visit("/accounts")
    |> assert_has(css("[data-test='nav-agency-dashboard']"))

    # Step 2: Navigate to /agency — empty dashboard renders.
    session
    |> visit("/agency")
    |> assert_has(css("[data-test='agency-client-dashboard']"))

    # Step 3: Fill client creation form and submit.
    client_name = "Journey4 Client #{System.unique_integer([:positive])}"

    session
    |> visit("/agency/clients/new")
    |> assert_has(css("[data-test='client-form']"))
    |> fill_in(css("input[name='client[name]']"), with: client_name)
    |> click(css("button[type='submit']"))

    # Step 4: Redirected to /agency — dashboard shows the new client row.
    # The row is marked as originator (agency created it).
    session
    |> visit("/agency")
    |> assert_has(css("[data-test='client-row-originator']"))
    |> assert_has(css("[data-test='enter-client']"))

    # Step 5: Click enter-client to switch active scope into the client account.
    click(session, css("[data-test='enter-client']"))

    # Step 6: After scope switch, /accounts shows the inside-client indicator.
    session
    |> visit("/accounts")
    |> assert_has(css("[data-test='inside-client-indicator']"))
  end
end
