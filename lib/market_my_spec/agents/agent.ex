defmodule MarketMySpec.Agents.Agent do
  @moduledoc """
  Paired-agent-binary record. Owned by a user; one user may own many
  agents (per-machine). All of a user's agents share one channel topic
  `agents:<user_id>` — agent_id is used to route specific http_request
  envelopes within that topic.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agents" do
    field :name, :string
    field :version, :string
    field :status, Ecto.Enum, values: [:active, :revoked], default: :active
    field :last_seen_at, :utc_datetime_usec
    field :paired_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :encrypted_token, :binary
    field :token_hash, :binary

    belongs_to :user, MarketMySpec.Users.User, type: :id

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Computed channel topic — `agents:<user_id>`, shared by all of a user's agents."
  def channel_topic(%__MODULE__{user_id: user_id}), do: "agents:#{user_id}"

  def create_changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :user_id,
      :name,
      :version,
      :status,
      :paired_at,
      :encrypted_token,
      :token_hash
    ])
    |> validate_required([:user_id, :name, :paired_at, :encrypted_token, :token_hash])
    |> assoc_constraint(:user)
    |> unique_constraint(:token_hash)
  end

  def revoke_changeset(agent, now \\ DateTime.utc_now()) do
    change(agent, status: :revoked, revoked_at: now, encrypted_token: <<>>)
  end

  def touch_changeset(agent, now \\ DateTime.utc_now()) do
    change(agent, last_seen_at: now)
  end
end
