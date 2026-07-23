defmodule IeeeTamuPortal.Repo.Migrations.AddPrivateToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :private, :boolean, default: false, null: false
    end
  end
end
