defmodule IeeeTamuPortal.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add :name, :string, null: false, size: 100
      add :token_hash, :binary, null: false, size: 32
      add :prefix, :string, null: false, size: 30
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_keys, [:token_hash])
    create index(:api_keys, [:is_active])
    create index(:api_keys, [:name])
  end
end
