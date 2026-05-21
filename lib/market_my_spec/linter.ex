defmodule MarketMySpec.Linter do
  @moduledoc """
  Per-account prose linting.

  Stores one `.vale.ini` body per Account and runs a `Linter` implementation
  against polished prose. Vale is the v1 implementation; tests use a deterministic
  stub configured via `:market_my_spec, :linter_impl`.

  When no configuration is saved, `lint/2` returns `{:ok, []}` — lint is advisory
  and the absence of a configuration is a no-op, not an error.
  """

  alias MarketMySpec.Linter.Config
  alias MarketMySpec.Linter.ConfigsRepository
  alias MarketMySpec.Users.Scope

  @type alert :: %{
          required(:severity) => String.t(),
          required(:check) => String.t(),
          required(:line) => pos_integer(),
          required(:column) => pos_integer(),
          required(:message) => String.t()
        }

  @doc """
  Returns the configured Linter implementation module. Defaults to
  `MarketMySpec.Linter.Vale` in dev/prod; `:test` overrides to
  `MarketMySpec.Linter.TestStub`.
  """
  @spec impl() :: module()
  def impl, do: Application.get_env(:market_my_spec, :linter_impl, MarketMySpec.Linter.Vale)

  @doc """
  Saves a `.vale.ini` body on the scoped Account. Validates via the
  implementation's `validate_config/1` before persisting. On validation
  failure, returns `{:error, error_text}` and the prior configuration is
  unchanged.
  """
  @spec save_config(Scope.t(), String.t()) ::
          {:ok, Config.t()} | {:error, String.t() | Ecto.Changeset.t()}
  def save_config(%Scope{active_account_id: account_id}, vale_ini)
      when is_binary(account_id) and is_binary(vale_ini) do
    case impl().validate_config(vale_ini) do
      :ok -> ConfigsRepository.upsert(account_id, vale_ini)
      {:error, _} = error -> error
    end
  end

  @doc """
  Returns the saved `.vale.ini` body for the scoped Account, or
  `{:error, :no_config}` when nothing has been saved.
  """
  @spec get_config(Scope.t()) :: {:ok, String.t()} | {:error, :no_config}
  def get_config(%Scope{active_account_id: account_id}) when is_binary(account_id) do
    case ConfigsRepository.get_by_account_id(account_id) do
      {:ok, %Config{vale_ini: vale_ini}} -> {:ok, vale_ini}
      {:error, :not_found} -> {:error, :no_config}
    end
  end

  @doc """
  Removes the saved `.vale.ini` for the scoped Account. Idempotent —
  clearing an already-cleared Account returns `:ok`.
  """
  @spec clear_config(Scope.t()) :: :ok
  def clear_config(%Scope{active_account_id: account_id}) when is_binary(account_id) do
    ConfigsRepository.delete_by_account_id(account_id)
  end

  @doc """
  Lints prose against the scoped Account's saved Vale configuration.

  Returns `{:ok, alerts}` — a flat list of agent-friendly alert maps
  (severity, check, line, column, message). When no configuration is
  saved on the account, returns `{:ok, []}`.
  """
  @spec lint(Scope.t(), String.t()) :: {:ok, [alert()]} | {:error, String.t()}
  def lint(%Scope{} = scope, prose) when is_binary(prose) do
    case get_config(scope) do
      {:ok, vale_ini} -> impl().lint(vale_ini, prose)
      {:error, :no_config} -> {:ok, []}
    end
  end
end
