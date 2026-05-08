defmodule MarketMySpecWeb.UserOAuthController do
  @moduledoc """
  Handles Google (and future provider) sign-in via OAuth for anonymous users.

  Distinct from `IntegrationsController`, which handles OAuth for already
  authenticated users adding data-import integrations. This controller lets
  anonymous visitors sign up or sign in via OAuth in one click.

  Routes (public, no auth required):
    GET /auth/:provider           — redirect to provider authorization page
    GET /auth/:provider/callback  — exchange code, create/find user, log in
  """

  use MarketMySpecWeb, :controller

  alias MarketMySpec.Integrations
  alias MarketMySpec.Integrations.OAuthStateStore
  alias MarketMySpec.Users
  alias MarketMySpec.Users.Scope
  alias MarketMySpecWeb.UserAuth

  require Logger

  @doc """
  Initiates the OAuth flow by redirecting to the provider's authorization page.
  """
  def request(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)
    redirect_uri = callback_url(provider)

    result =
      try do
        Integrations.authorize_url(provider, redirect_uri)
      rescue
        e ->
          Logger.error("OAuth authorize_url failed for #{provider}: #{inspect(e)}")
          {:error, :transport_error}
      end

    case result do
      {:ok, %{url: url, session_params: session_params}} ->
        state = Map.get(session_params, "state") || Map.get(session_params, :state)
        if state, do: OAuthStateStore.store(state, session_params)

        conn
        |> put_session(:sign_in_oauth_provider, provider)
        |> redirect(external: url)

      {:error, reason} ->
        Logger.error("Failed to generate OAuth URL for #{provider}: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to connect to #{format_provider(provider)}. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  Handles the OAuth callback: exchanges the code for tokens, looks up or
  creates a user by email, then logs them in via the standard session mechanism.
  """
  def callback(conn, params) do
    provider = get_session(conn, :sign_in_oauth_provider)
    conn = delete_session(conn, :sign_in_oauth_provider)

    state = Map.get(params, "state")

    session_params =
      if state do
        case OAuthStateStore.fetch(state) do
          {:ok, sp} -> sp
          :error -> %{}
        end
      else
        %{}
      end

    case Map.get(params, "error") do
      nil ->
        handle_oauth_callback(conn, provider, params, session_params)

      error ->
        conn
        |> put_flash(:error, format_oauth_error(error, params))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp handle_oauth_callback(conn, provider, params, session_params) do
    redirect_uri = callback_url(provider)

    with {:ok, provider_mod} <- fetch_provider_module(provider),
         config =
           provider_mod.config(redirect_uri)
           |> Keyword.put(:session_params, session_params),
         strategy = provider_mod.strategy(),
         {:ok, callback_result} <- strategy.callback(config, params),
         user_data = Map.get(callback_result, :user) || %{},
         token = Map.get(callback_result, :token) || %{},
         {:ok, normalized} <- provider_mod.normalize_user(user_data),
         {:ok, email} <- require_email(normalized) do
      user = resolve_or_create_user(provider, normalized, email)
      _ = persist_integration(user, provider, token, normalized)

      conn
      |> put_flash(:info, "Signed in successfully.")
      |> UserAuth.log_in_user(user)
    else
      {:error, :unsupported_provider} ->
        conn
        |> put_flash(:error, "Unsupported sign-in provider.")
        |> redirect(to: ~p"/users/log-in")

      {:error, :missing_email} ->
        conn
        |> put_flash(:error, "Your #{format_provider(provider)} account did not share an email address.")
        |> redirect(to: ~p"/users/log-in")

      {:error, reason} ->
        Logger.error("OAuth sign-in callback failed for #{provider}: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Sign-in with #{format_provider(provider)} failed. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp require_email(%{email: email}) when is_binary(email) and byte_size(email) > 0,
    do: {:ok, email}

  defp require_email(_), do: {:error, :missing_email}

  # Resolution priority:
  #   1. By (provider, provider_user_id) — the same provider account, even if
  #      the user changed their primary email upstream (criterion 5681).
  #   2. By email — a different provider on the same person's email
  #      (e.g. signed up with Google, now signing in via GitHub on the same
  #      address).
  #   3. Otherwise, create a new user.
  defp resolve_or_create_user(provider, %{provider_user_id: pid}, email)
       when is_binary(pid) and byte_size(pid) > 0 do
    case Integrations.find_user_id_by_provider_identity(provider, pid) do
      nil -> Users.get_user_by_email(email) || create_user_from_oauth!(email)
      user_id -> Users.get_user!(user_id)
    end
  end

  defp resolve_or_create_user(_provider, _normalized, email) do
    Users.get_user_by_email(email) || create_user_from_oauth!(email)
  end

  defp create_user_from_oauth!(email) do
    case Users.register_user(%{email: email}) do
      {:ok, user} ->
        user

      {:error, changeset} ->
        raise "Failed to create user from OAuth: #{inspect(changeset.errors)}"
    end
  end

  # Stores the OAuth identity (provider_user_id lives in provider_metadata)
  # plus the access/refresh tokens for the integration. Failures here must
  # not block sign-in — the user is already authenticated by the time we
  # reach this point.
  defp persist_integration(user, provider, token, normalized) do
    scope = Scope.for_user(user)
    attrs = Integrations.build_integration_attrs(token, normalized)

    case Integrations.upsert_integration(scope, provider, attrs) do
      {:ok, integration} ->
        {:ok, integration}

      {:error, reason} ->
        Logger.warning(
          "Failed to persist OAuth integration for user_id=#{user.id} provider=#{provider}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp fetch_provider_module(provider) do
    providers = Application.get_env(:market_my_spec, :oauth_providers, %{})

    case Map.fetch(providers, provider) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, :unsupported_provider}
    end
  end

  defp callback_url(provider) do
    MarketMySpecWeb.Endpoint.url() <> ~p"/auth/#{provider}/callback"
  end

  defp format_provider(:google), do: "Google"
  defp format_provider(:github), do: "GitHub"
  defp format_provider(provider), do: provider |> to_string() |> String.capitalize()

  defp format_oauth_error("access_denied", _params),
    do: "You denied access. Please try again if you want to sign in."

  defp format_oauth_error(error, %{"error_description" => desc}),
    do: "OAuth error: #{desc} (#{error})"

  defp format_oauth_error(error, _params), do: "OAuth error: #{error}"
end
