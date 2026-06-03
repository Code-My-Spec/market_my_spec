defmodule MarketMySpec.Repo.Migrations.CreateProblemDiscoveryRedTeamVerdicts do
  use Ecto.Migration

  def change do
    create table(:problem_discovery_red_team_verdicts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :candidate_id,
          references(:problem_discovery_candidates, type: :binary_id, on_delete: :delete_all),
          null: false

      add :verdict, :string, null: false
      add :kill_argument, :text, null: false
      add :cheapest_kill_test, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:problem_discovery_red_team_verdicts, [:candidate_id])
  end
end
