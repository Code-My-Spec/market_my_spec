defmodule MarketMySpec.Linter.ConfigsRepository do
  @moduledoc """
  Persistence for `Linter.Config` rows. Account-scoped CRUD only.
  """

  import Ecto.Query

  alias MarketMySpec.Linter.Config
  alias MarketMySpec.Repo

  @spec get_by_account_id(Ecto.UUID.t()) ::
          {:ok, Config.t()} | {:error, :not_found}
  def get_by_account_id(account_id) when is_binary(account_id) do
    case Repo.get_by(Config, account_id: account_id) do
      nil -> {:error, :not_found}
      %Config{} = config -> {:ok, config}
    end
  end

  @spec upsert(Ecto.UUID.t(), String.t()) ::
          {:ok, Config.t()} | {:error, Ecto.Changeset.t()}
  def upsert(account_id, vale_ini) when is_binary(account_id) and is_binary(vale_ini) do
    now = DateTime.utc_now()

    %Config{}
    |> Config.changeset(%{account_id: account_id, vale_ini: vale_ini})
    |> Repo.insert(
      on_conflict: [set: [vale_ini: vale_ini, updated_at: now]],
      conflict_target: [:account_id],
      returning: true
    )
  end

  @spec delete_by_account_id(Ecto.UUID.t()) :: :ok
  def delete_by_account_id(account_id) when is_binary(account_id) do
    from(c in Config, where: c.account_id == ^account_id)
    |> Repo.delete_all()

    :ok
  end
end
