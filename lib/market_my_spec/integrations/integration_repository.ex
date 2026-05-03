defmodule MarketMySpec.Integrations.IntegrationRepository do
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
