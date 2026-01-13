defmodule IeeeTamuPortal.Repo.Migrations.AddRsvpableToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :rsvpable, :boolean, default: true, null: false
    end
  end
end
