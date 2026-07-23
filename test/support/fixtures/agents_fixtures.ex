defmodule MarketMySpec.AgentsFixtures do
  @moduledoc """
  Test fixtures for `MarketMySpec.Agents`. Inserts Agent rows directly
  through `AgentsRepository.create_agent/3` so BDD specs can precondition
  channel-join and dispatch flows without driving the full pairing UI.
  """

  alias MarketMySpec.Agents
  alias MarketMySpec.Agents.AgentsRepository

  @doc """
  Creates an `:active` agent owned by `user`. Returns `{agent, plaintext_token}`.

  Attrs:
    * `:name`    — defaults to a unique "spex-agent-<n>" label
    * `:version` — defaults to "0.0.1"
  """
  def agent_fixture(user, attrs \\ %{}) do
    token = Agents.generate_token()
    token_hash = Agents.hash_token(token)

    name = Map.get(attrs, :name) || "spex-agent-#{System.unique_integer([:positive])}"
    version = Map.get(attrs, :version) || "0.0.1"

    {:ok, agent} =
      AgentsRepository.create_agent(user.id, name, %{
        version: version,
        status: :active,
        encrypted_token: token,
        token_hash: token_hash
      })

    {agent, token}
  end

  @doc "Creates a revoked agent owned by `user`. Returns the agent."
  def revoked_agent_fixture(user, attrs \\ %{}) do
    {agent, _token} = agent_fixture(user, attrs)
    {:ok, revoked} = AgentsRepository.revoke_agent(user.id, agent.id)
    revoked
  end
end
