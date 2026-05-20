defmodule MarketMySpec.Agents.HostAllowlist do
  @moduledoc """
  Pre-dispatch host validation so the agent never executes arbitrary
  HTTP. `allowed?/1` accepts only URLs whose host is in the configured
  allowlist (or a subdomain of an allowed host).
  """

  @default_allowed ["reddit.com", "oauth.reddit.com"]

  @doc "Returns true if `url`'s host is allowlisted."
  def allowed?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) ->
        host = String.downcase(host)
        Enum.any?(allowed_hosts(), &host_matches?(host, &1))

      _ ->
        false
    end
  end

  def allowed?(_), do: false

  @doc "Runtime-readable list of allowed host suffixes."
  def allowed_hosts do
    Application.get_env(:market_my_spec, :agent_allowed_hosts, @default_allowed)
  end

  defp host_matches?(host, allowed) do
    host == allowed or String.ends_with?(host, "." <> allowed)
  end
end
