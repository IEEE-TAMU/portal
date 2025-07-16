defmodule IeeeTamuPortal.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add :amount, :decimal
      add :confirmation_code, :string
      add :tshirt_size, :string
      add :contact_email, :string
      add :name, :string
      add :registration_id, references(:registrations, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:confirmation_code])
    create unique_index(:payments, [:registration_id])
  end
end
