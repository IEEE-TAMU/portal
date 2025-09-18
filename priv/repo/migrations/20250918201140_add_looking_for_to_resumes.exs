defmodule IeeeTamuPortal.Repo.Migrations.AddLookingForToResumes do
  use Ecto.Migration

  def change do
    alter table(:resumes) do
      add :looking_for, :string, null: false, default: "either"
    end

    create index(:resumes, [:looking_for])
  end
end
