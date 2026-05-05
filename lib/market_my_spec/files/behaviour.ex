defmodule MarketMySpec.Files.Behaviour do
  @moduledoc """
  Storage backend contract for the Files context.

  Adapters (e.g. `MarketMySpec.Files.S3`) implement this behaviour to plug
  into the configured storage backend slot. Keys passed to callbacks are
  already account-scoped — callers (the Files context, driven by the MCP
  file tools) prefix every key with `accounts/{account_id}/` before
  invoking the adapter. The adapter never reasons about tenancy.

  This contract is intentionally narrow: persistence primitives only. The
  read-before-edit gate, path validation, account prefix resolution, and
  the agent-facing tool surface (`read_file`, `write_file`, `edit_file`,
  `delete_file`, `list_files`) all live above this layer.
  """

  @type key :: String.t()
  @type prefix :: String.t()
  @type body :: binary()
  @type opts :: keyword()
  @type metadata :: %{
          required(:key) => key(),
          optional(:size) => non_neg_integer(),
          optional(:last_modified) => DateTime.t(),
          optional(:content_type) => String.t()
        }

  @callback put(key(), body(), opts()) :: {:ok, metadata()} | {:error, term()}
  @callback get(key()) :: {:ok, body()} | {:error, :not_found | term()}
  @callback list(prefix()) :: {:ok, [metadata()]} | {:error, term()}
  @callback delete(key()) :: :ok | {:error, :not_found | term()}
end
