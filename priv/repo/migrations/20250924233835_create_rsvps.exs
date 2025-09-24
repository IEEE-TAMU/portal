defmodule IeeeTamuPortal.Repo.Migrations.CreateRsvps do
  use Ecto.Migration

  def change do
    create table(:rsvps) do
      add :member_id, references(:members, on_delete: :nothing)
      add :event_uid, references(:events, on_delete: :nothing, column: :uid, type: :uuid)

      timestamps(type: :utc_datetime)
    end

    create index(:rsvps, [:member_id])
    create index(:rsvps, [:event_uid])
    create unique_index(:rsvps, [:member_id, :event_uid])
  end
end
