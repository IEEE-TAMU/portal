defmodule IeeeTamuPortal.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :uid, :uuid, primary_key: true
      add :dtstart, :utc_datetime, null: false
      add :dtend, :utc_datetime
      add :summary, :string, null: false
      add :description, :text
      add :location, :string
      add :organizer, :string
      add :rsvp_limit, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
