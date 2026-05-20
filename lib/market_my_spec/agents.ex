defmodule MarketMySpec.Agents do
  @moduledoc """
  Context for user-paired local agent binaries. Owns Agent records
  (per-user paired binaries with encrypted long-lived tokens), the
  pairing flow that turns a user's in-browser consent into a stored
  Agent + issued token, presence tracking, and the dispatcher that
  broadcasts HTTP envelopes over the per-user channel.
  """

  alias MarketMySpec.Agents.AgentsRepository

  defdelegate list_agents(user_id), to: AgentsRepository
  defdelegate get_agent(user_id, agent_id), to: AgentsRepository
  defdelegate revoke_agent(user_id, agent_id), to: AgentsRepository

  @doc """
  Hashes a plaintext token. The hash is stored in `agents.token_hash`
  (unique-indexed) so AgentChannel can look up the agent on join
  without decrypting.
  """
  def hash_token(plaintext) when is_binary(plaintext) do
    :crypto.hash(:sha256, plaintext)
  end

  @doc "Generates a fresh opaque token (44 base64 chars of 32 random bytes)."
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
