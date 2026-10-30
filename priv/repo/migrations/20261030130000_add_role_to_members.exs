defmodule IeeeTamuPortal.Repo.Migrations.AddRoleToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :role, :string, null: false, default: "member", size: 20
    end

    create index(:members, [:role])
  end
end
