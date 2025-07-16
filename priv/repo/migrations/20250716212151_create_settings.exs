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
  end
end
