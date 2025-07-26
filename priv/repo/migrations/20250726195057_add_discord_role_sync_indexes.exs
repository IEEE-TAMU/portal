defmodule IeeeTamuPortal.Repo.Migrations.AddDiscordRoleSyncIndexes do
  use Ecto.Migration

  def change do
    # Add index for querying registrations by member_id and year for payment status checks
    create index(:registrations, [:member_id, :year], name: :registrations_member_year_index)

    # Add index for querying auth methods by provider for Discord role sync
    create index(:secondary_auth_methods, [:provider], name: :auth_methods_provider_index)

    # Add composite index for efficient Discord member queries
    create index(:secondary_auth_methods, [:provider, :member_id],
             name: :auth_methods_provider_member_index
           )
  end
end
