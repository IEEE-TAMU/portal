defmodule IeeeTamuPortal.Repo.Migrations.CreateSecondaryAuthMethods do
  use Ecto.Migration

  def change do
    create table(:secondary_auth_methods, primary_key: false) do
      add :member_id, references(:members, on_delete: :delete_all), primary_key: true
      add :provider, :string, primary_key: true
      add :sub, :string, null: false
      add :preferred_username, :string
      add :email, :string
      add :email_verified, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:secondary_auth_methods, [:member_id, :provider])
    create unique_index(:secondary_auth_methods, [:provider, :sub])
  end
end
