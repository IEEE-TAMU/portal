defmodule IeeeTamuPortal.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations) do
      add :year, :integer, null: false
      add :confirmation_code, :string
      add :payment_override, :boolean, default: false, null: false
      add :member_id, references(:members, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:registrations, [:confirmation_code])
    create unique_index(:registrations, [:member_id, :year])
    create index(:registrations, [:member_id])
  end
end
