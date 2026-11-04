defmodule IeeeTamuPortal.Repo.Migrations.AddEventUidToEventCheckins do
  use Ecto.Migration

  def change do
    alter table(:event_checkins) do
      add :event_uid, :uuid, null: true
    end

    create index(:event_checkins, [:event_uid])
  end
end
