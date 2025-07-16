defmodule IeeeTamuPortal.Repo.Migrations.AddDefaultSettings do
  use Ecto.Migration

  def up do
    # Insert default settings
    execute """
    INSERT INTO settings (`key`, value, description, inserted_at, updated_at) VALUES
    ('registration_year', '2025', 'Current year for member registrations', NOW(), NOW()),
    ('current_event', 'NONE', 'Current active event', NOW(), NOW())
    """
  end

  def down do
    # Remove the default settings
    execute "DELETE FROM settings WHERE `key` IN ('registration_year', 'current_event')"
  end
end
