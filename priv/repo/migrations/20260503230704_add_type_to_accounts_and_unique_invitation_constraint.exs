defmodule MarketMySpec.Repo.Migrations.AddTypeToAccountsAndUniqueInvitationConstraint do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :type, :string, null: false, default: "individual"
    end

    create unique_index(:invitations, [:account_id, :email],
             where: "status = 'pending'",
             name: :invitations_account_id_email_pending_index
           )
  end
end
