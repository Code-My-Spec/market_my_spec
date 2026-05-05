defmodule MarketMySpec.Oauth.Application do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :market_my_spec
  import Ecto.Changeset

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:name, :redirect_uri, :scopes, :uid, :secret])
    |> validate_required([:name, :uid, :secret])
    |> validate_redirect_uris()
    |> unique_constraint(:uid)
  end

  defp validate_redirect_uris(changeset) do
    validate_change(changeset, :redirect_uri, fn :redirect_uri, redirect_uri ->
      redirect_uri
      |> String.split(" ", trim: true)
      |> Enum.flat_map(&redirect_uri_errors/1)
    end)
  end

  defp redirect_uri_errors(uri) do
    case validate_single_redirect_uri(uri) do
      :ok -> []
      {:error, message} -> [{:redirect_uri, message}]
    end
  end

  defp validate_single_redirect_uri(uri) do
    case URI.parse(uri) do
      %URI{scheme: "https"} ->
        :ok

      %URI{scheme: "http", host: host} when host in ["localhost", "127.0.0.1", "::1"] ->
        :ok

      %URI{scheme: "http"} ->
        {:error, "must use HTTPS except for localhost"}

      %URI{scheme: nil} ->
        {:error, "must be an absolute URI with a scheme"}

      _ ->
        :ok
    end
  end
end
