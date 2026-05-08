defmodule MarketMySpecWeb.Plugs.AgencyHost do
  @moduledoc """
  Endpoint plug that reads the request host and routes accordingly.

  - Apex `marketmyspec.com` → pass through unchanged
  - Recognized agency subdomain → assign `:current_agency` on the conn
    and stash `current_agency_id` in the session for downstream
    LiveViews
  - Unrecognized subdomain → 302 redirect to apex
  - API endpoints (`/oauth/*`, `/mcp`, `/.well-known/*`,
    `/auth/*`, `/integrations/oauth/*`) on a subdomain → 302 redirect
    to apex (apex-only contract)
  - Pass-through prefixes (`/up`, `/assets/*`, dev-mode paths) are
    served on every host without resolution
  """

  import Plug.Conn

  alias MarketMySpec.Agencies.HostResolver

  @api_prefixes ~w(/oauth /mcp /.well-known /auth /integrations/oauth)
  @passthrough_prefixes ~w(/assets /up /phoenix /dev /live)

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, _opts) do
    cond do
      passthrough?(conn) ->
        conn

      api_path?(conn) ->
        handle_api_path(conn)

      true ->
        handle_browser_path(conn)
    end
  end

  defp passthrough?(conn) do
    Enum.any?(@passthrough_prefixes, &String.starts_with?(conn.request_path, &1))
  end

  defp api_path?(conn) do
    Enum.any?(@api_prefixes, &String.starts_with?(conn.request_path, &1))
  end

  defp handle_api_path(conn) do
    case classify_host(conn) do
      {:agency, _} -> redirect_to_apex(conn)
      :unrecognized_subdomain -> redirect_to_apex(conn)
      _ -> conn
    end
  end

  defp handle_browser_path(conn) do
    case classify_host(conn) do
      {:agency, agency} ->
        conn
        |> assign(:current_agency, agency)
        |> fetch_session()
        |> put_session(:current_agency_id, agency.id)

      :unrecognized_subdomain ->
        redirect_to_apex(conn)

      _ ->
        conn
    end
  end

  defp classify_host(conn) do
    apex = HostResolver.apex_host()
    host = String.downcase(conn.host || "")

    cond do
      host == apex ->
        :apex

      String.ends_with?(host, "." <> apex) ->
        case HostResolver.resolve_host(host) do
          {:ok, agency} -> {:agency, agency}
          :none -> :unrecognized_subdomain
        end

      true ->
        :unrelated
    end
  end

  defp redirect_to_apex(conn) do
    apex = HostResolver.apex_host()
    target = "https://#{apex}#{conn.request_path}"

    conn
    |> put_resp_header("location", target)
    |> resp(302, "")
    |> halt()
  end
end
