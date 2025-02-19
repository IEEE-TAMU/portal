defmodule IeeeTamuPortal.Repo.Migrations.CreateMembersAuthTables do
  use Ecto.Migration

  def change do
    create table(:members) do
      add :email, :string, null: false, size: 160
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:members, [:email])

    create table(:members_tokens) do
      add :member_id, references(:members, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:members_tokens, [:member_id])
    create unique_index(:members_tokens, [:context, :token])
  end
end
