defmodule MarketMySpec.Agents.AgentsRepository do
  @moduledoc """
  User-scoped CRUD over `Agent` records. Cross-user access fails with
  `:not_found` — never returns another user's agent.
  """

  import Ecto.Query

  alias MarketMySpec.Agents.Agent
  alias MarketMySpec.Repo

  def list_agents(user_id) do
    Agent
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc "Returns a MapSet of active agent ids for the user. Used by Dispatcher to filter Presence."
  def active_agent_id_set(user_id) do
    Agent
    |> where([a], a.user_id == ^user_id and a.status == ^:active)
    |> select([a], a.id)
    |> Repo.all()
    |> MapSet.new()
  end

  def get_agent(user_id, agent_id) do
    case Repo.get_by(Agent, id: agent_id, user_id: user_id) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  def get_active_by_token_hash(token_hash) do
    case Repo.get_by(Agent, token_hash: token_hash, status: :active) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  def create_agent(user_id, name, token_attrs) do
    %Agent{}
    |> Agent.create_changeset(
      Map.merge(
        %{
          user_id: user_id,
          name: name,
          paired_at: DateTime.utc_now()
        },
        token_attrs
      )
    )
    |> Repo.insert()
  end

  def revoke_agent(user_id, agent_id) do
    with {:ok, agent} <- get_agent(user_id, agent_id) do
      agent |> Agent.revoke_changeset() |> Repo.update()
    end
  end

  def touch_last_seen(user_id, agent_id) do
    with {:ok, agent} <- get_agent(user_id, agent_id) do
      agent |> Agent.touch_changeset() |> Repo.update()
    end
  end

  def update_version(user_id, agent_id, version) do
    with {:ok, agent} <- get_agent(user_id, agent_id) do
      agent
      |> Ecto.Changeset.change(version: version)
      |> Repo.update()
    end
  end
end
