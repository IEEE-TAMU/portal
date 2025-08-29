defmodule IeeeTamuPortal.Repo.Migrations.CreateEventCheckins do
  use Ecto.Migration

  def change do
    create table(:event_checkins) do
      add :event_name, :string, null: false
      add :event_year, :integer, null: false
      add :member_id, references(:members, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:event_checkins, [:member_id])
    create unique_index(:event_checkins, [:member_id, :event_name, :event_year])
  end
end
