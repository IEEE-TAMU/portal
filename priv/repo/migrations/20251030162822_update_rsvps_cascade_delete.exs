defmodule IeeeTamuPortal.Repo.Migrations.UpdateRsvpsCascadeDelete do
  use Ecto.Migration

  def up do
    # Drop the existing foreign key constraint
    drop constraint(:rsvps, "rsvps_event_uid_fkey")

    # Add the foreign key constraint with cascade delete
    alter table(:rsvps) do
      modify :event_uid, references(:events, on_delete: :delete_all, column: :uid, type: :uuid)
    end
  end

  def down do
    # Drop the cascade delete foreign key constraint
    drop constraint(:rsvps, "rsvps_event_uid_fkey")

    # Add back the original foreign key constraint without cascade
    alter table(:rsvps) do
      modify :event_uid, references(:events, on_delete: :nothing, column: :uid, type: :uuid)
    end
  end
end
