defmodule IeeeTamuPortal.Repo.Migrations.CreateResumes do
  use Ecto.Migration

  def change do
    create table(:resumes) do
      add :original_filename, :string, null: false
      add :bucket_url, :string, null: false
      add :key, :string, null: false
      add :member_id, references(:members, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:resumes, [:member_id])
  end
end
