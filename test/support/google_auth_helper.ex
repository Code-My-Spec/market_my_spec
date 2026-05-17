defmodule MarketMySpec.GoogleAuthHelper do
  @moduledoc """
  Helper for getting Google OAuth tokens during cassette re-recording.

  Only used when re-recording cassettes against the real Google
  Analytics Admin API. Regular test runs replay cassettes and never
  invoke this module.

  Checks these sources in order:
  1. `GOOGLE_ACCESS_TOKEN` env var (short-lived, ~1 hour)
  2. `GOOGLE_REFRESH_TOKEN` env var (long-lived; exchanged for an
     access token)
  3. Raises with re-record instructions if none available.
  """

  def get_token do
    cond do
      access_token = System.get_env("GOOGLE_ACCESS_TOKEN") ->
        access_token

      refresh_token = System.get_env("GOOGLE_REFRESH_TOKEN") ->
        exchange_refresh_token(refresh_token)

      true ->
        raise """
        No Google OAuth token found. To record real API cassettes, set one of:

        1. GOOGLE_ACCESS_TOKEN (short-lived, ~1 hour):
           export GOOGLE_ACCESS_TOKEN="ya29.a0..."
           RERECORD=1 mix test test/market_my_spec/mcp_servers/analytics_admin

        2. GOOGLE_REFRESH_TOKEN (long-lived, can be reused):
           export GOOGLE_REFRESH_TOKEN="1//0..."
           RERECORD=1 mix test test/market_my_spec/mcp_servers/analytics_admin

        To get a refresh token:
        1. Go to https://developers.google.com/oauthplayground/
        2. Settings (⚙️) → Use your own OAuth credentials
        3. Enter GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
        4. Select: https://www.googleapis.com/auth/analytics.edit
        5. Authorize and exchange code
        6. Copy the "Refresh token" (starts with "1//0")
        """
    end
  end

  def exchange_refresh_token(refresh_token) do
    client_id = Application.fetch_env!(:market_my_spec, :google_client_id)
    client_secret = Application.fetch_env!(:market_my_spec, :google_client_secret)

    body =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      })

    case Req.post("https://oauth2.googleapis.com/token",
           body: body,
           headers: [{"content-type", "application/x-www-form-urlencoded"}]
         ) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        access_token

      {:ok, %{status: status, body: body}} ->
        raise """
        Failed to exchange refresh token (HTTP #{status}):
        #{inspect(body)}

        Your refresh token may be expired or invalid.
        Get a new one from: https://developers.google.com/oauthplayground/
        """

      {:error, reason} ->
        raise """
        Failed to exchange refresh token:
        #{inspect(reason)}
        """
    end
  end

  def get_connection do
    token = get_token()
    GoogleApi.AnalyticsAdmin.V1beta.Connection.new(token)
  end
end
