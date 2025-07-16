defmodule IeeeTamuPortal.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string
      add :value, :string
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:key])

    execute """
            INSERT INTO settings (`key`, value, description, inserted_at, updated_at) VALUES
            ('registration_year', '2025', 'Current year for member registrations', NOW(), NOW()),
            ('current_event', 'NONE', 'Current active event', NOW(), NOW())
            """,
            "DELETE FROM settings WHERE `key` IN ('registration_year', 'current_event')"
  end
end
