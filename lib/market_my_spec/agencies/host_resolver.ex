defmodule MarketMySpec.Agencies.HostResolver do
  @moduledoc """
  Resolves a request host to an agency account by subdomain match and
  manages an agency's subdomain claim.

  The platform's apex host is `marketmyspec.com`. Requests to
  `<subdomain>.marketmyspec.com` resolve into the agency that currently
  claims `<subdomain>`. Requests to the apex (or to any unrecognized
  subdomain) return `:none` — the host plug treats those as
  apex/redirect-to-apex respectively.

  No history is kept of previously-claimed subdomains: a subdomain that
  has been changed away from is indistinguishable from one never claimed,
  and both resolve to `:none`.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Repo

  @apex_host Application.compile_env(:market_my_spec, :apex_host, "marketmyspec.com")

  @doc """
  Resolves a request host string to an agency `Account`.

  Returns `{:ok, account}` if the host is `<subdomain>.<apex>` and an
  agency currently claims that subdomain. Returns `:none` for the apex
  itself and for any subdomain not currently held by an agency.
  """
  @spec resolve_host(String.t()) :: {:ok, Account.t()} | :none
  def resolve_host(host) when is_binary(host) do
    host
    |> normalize()
    |> extract_subdomain()
    |> lookup_subdomain()
  end

  @doc """
  Sets or changes the subdomain on an agency account.

  Validates format, reserved-name exclusion, and uniqueness. The account
  must be of type `:agency`; individual-typed accounts are rejected.
  """
  @spec claim_subdomain(Account.t(), String.t()) ::
          {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  def claim_subdomain(%Account{} = account, subdomain) when is_binary(subdomain) do
    account
    |> Account.subdomain_changeset(%{subdomain: subdomain})
    |> Repo.update()
  end

  @doc """
  Returns the configured apex host (e.g. `"marketmyspec.com"`).
  """
  @spec apex_host() :: String.t()
  def apex_host, do: @apex_host

  defp normalize(host) do
    host
    |> String.downcase()
    |> String.trim()
  end

  defp extract_subdomain(host) do
    apex = @apex_host

    case host do
      ^apex -> :apex
      _ -> match_subdomain(host, apex)
    end
  end

  defp match_subdomain(host, apex) do
    suffix = "." <> apex

    case String.ends_with?(host, suffix) do
      true -> String.replace_suffix(host, suffix, "")
      false -> :unknown
    end
  end

  defp lookup_subdomain(:apex), do: :none
  defp lookup_subdomain(:unknown), do: :none
  defp lookup_subdomain(""), do: :none

  defp lookup_subdomain(subdomain) when is_binary(subdomain) do
    query =
      from a in Account,
        where: a.type == :agency and a.subdomain == ^subdomain

    case Repo.one(query) do
      nil -> :none
      %Account{} = account -> {:ok, account}
    end
  end
end
