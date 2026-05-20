defmodule MarketMySpec.Agents.Pairing do
  @moduledoc """
  Pairing protocol. The binary picks a random state, opens
  `/agents/pair?state=...&port=...&name=...`. The LiveView calls
  `start_pairing/2` on mount to track the state's lifecycle, and
  `complete_pairing/3` on Approve to create the Agent + issue the
  one-time plaintext token.

  State tokens are single-use and live for 5 minutes. See
  `Pairing.StateStore` for the ETS-backed store.
  """

  alias MarketMySpec.Agents
  alias MarketMySpec.Agents.AgentsRepository
  alias MarketMySpec.Agents.Pairing.StateStore

  @ttl_ms 5 * 60 * 1000

  @doc """
  Validates and registers a freshly-opened pairing state.

  Returns:
    * `{:ok, :ready}` — state is new/fresh; show the approval screen.
    * `{:error, :consumed}` — state was already approved.
    * `{:error, :stale}` — state exists but is older than 5 minutes.
  """
  def start_pairing(_scope, %{"state" => state}) when is_binary(state) and state != "" do
    case StateStore.touch(state, @ttl_ms) do
      :fresh -> {:ok, :ready}
      :consumed -> {:error, :consumed}
      :stale -> {:error, :stale}
    end
  end

  def start_pairing(_scope, _params), do: {:error, :invalid_params}

  @doc """
  Marks the state consumed, creates the Agent record for the user,
  and returns `{:ok, %{token: plaintext, agent: agent}}`.

  Fails with `{:error, :consumed}` if the state was already used or
  `{:error, :stale}` if it's expired.
  """
  def complete_pairing(scope, state, agent_name)
      when is_binary(state) and is_binary(agent_name) do
    case StateStore.consume(state, @ttl_ms) do
      :ok ->
        plaintext = Agents.generate_token()
        token_hash = Agents.hash_token(plaintext)

        {:ok, agent} =
          AgentsRepository.create_agent(scope.user.id, agent_name, %{
            version: nil,
            status: :active,
            encrypted_token: plaintext,
            token_hash: token_hash
          })

        {:ok, %{token: plaintext, agent: agent}}

      {:error, _} = err ->
        err
    end
  end

  @doc "Marks a state consumed without issuing a token (Deny path)."
  def deny_pairing(state) when is_binary(state) do
    case StateStore.consume(state, @ttl_ms) do
      :ok -> :ok
      {:error, _} = err -> err
    end
  end
end
