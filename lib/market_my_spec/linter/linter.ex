defmodule MarketMySpec.Linter.Linter do
  @moduledoc """
  Behaviour for a prose linter. Vale is the v1 implementation; tests use a
  deterministic stub. Other prose linters (proselint native, write-good
  native, an LLM-backed linter) could implement this contract in the future.
  """

  @type alert :: %{
          required(:severity) => String.t(),
          required(:check) => String.t(),
          required(:line) => pos_integer(),
          required(:column) => pos_integer(),
          required(:message) => String.t()
        }

  @doc """
  Validate a `.vale.ini` body. Implementations should run the underlying
  linter's structural validator (e.g. `vale ls-config`) and return `:ok`
  on success or `{:error, error_text}` on a structural failure.
  """
  @callback validate_config(vale_ini :: String.t()) ::
              :ok | {:error, String.t()}

  @doc """
  Lint prose against a configuration. Returns `{:ok, alerts}` — a flat
  list of agent-friendly alert maps. An empty list means no violations.
  Returns `{:error, error_text}` only on a hard runtime failure
  (e.g. linter binary missing, config error).
  """
  @callback lint(vale_ini :: String.t(), prose :: String.t()) ::
              {:ok, [alert()]} | {:error, String.t()}
end
