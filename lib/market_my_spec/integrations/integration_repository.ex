defmodule MarketMySpec.Integrations.IntegrationRepository do
  @moduledoc """
  Repository for OAuth integration records, scoped to a user.
  """

  import Ecto.Query

  alias MarketMySpec.Integrations.Integration
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  def get_integration(%Scope{user: user}, provider) do
    result = from(i in Integration, where: i.user_id == ^user.id and i.provider == ^provider) |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  end

  def list_integrations(%Scope{user: user}) do
    from(i in Integration, where: i.user_id == ^user.id, order_by: [desc: i.inserted_at])
    |> Repo.all()
  end

  def create_integration(%Scope{user: user}, attrs) do
    attrs_with_user = Map.put(attrs, :user_id, user.id)

    %Integration{}
    |> Integration.changeset(attrs_with_user)
    |> Repo.insert()
  end

  def update_integration(%Scope{} = scope, provider, attrs) do
    with {:ok, integration} <- get_integration(scope, provider) do
      integration |> Integration.changeset(attrs) |> Repo.update()
    end
  end

  def delete_integration(%Scope{} = scope, provider) do
    with {:ok, integration} <- get_integration(scope, provider) do
      Repo.delete(integration)
    end
  end

  @doc """
  Returns the `user_id` of the integration whose `provider_metadata` carries
  the given `provider_user_id` for `provider`, or `nil` if none matches.

  Uses Postgres' `->>` JSONB accessor against `provider_metadata`. Used by
  the public OAuth sign-in flow to resolve a returning visitor by their
  stable provider identity (Google `sub`, GitHub `id`) so an email change
  does not produce a duplicate account.
  """
  @spec find_user_id_by_provider_identity(atom(), String.t()) :: integer() | nil
  def find_user_id_by_provider_identity(provider, provider_user_id)
      when is_binary(provider_user_id) do
    Integration
    |> where([i], i.provider == ^provider)
    |> where(
      [i],
      fragment("?->>'provider_user_id' = ?", i.provider_metadata, ^provider_user_id)
    )
    |> select([i], i.user_id)
    |> Repo.one()
  end

  def upsert_integration(%Scope{user: user}, provider, attrs) do
    attrs_with_user_and_provider =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:provider, provider)

    changeset = Integration.changeset(%Integration{}, attrs_with_user_and_provider)

    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:user_id, :provider]
    )
  end

  def connected?(%Scope{user: user}, provider) do
    from(i in Integration, where: i.user_id == ^user.id and i.provider == ^provider)
    |> Repo.exists?()
  end

  def with_expired_tokens(%Scope{user: user}) do
    now = DateTime.utc_now()
    from(i in Integration, where: i.user_id == ^user.id and i.expires_at < ^now)
    |> Repo.all()
  end
end
