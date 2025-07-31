defmodule IeeeTamuPortal.Repo.Migrations.UpdatePaymentsTable do
  use Ecto.Migration

  def change do
    # Modify the amount column to have proper decimal precision
    # Using precision 10 and scale 2 for currency (allows up to 99,999,999.99)
    alter table(:payments) do
      modify :amount, :decimal, precision: 10, scale: 2
    end
    
    # Remove the contact_email column
    alter table(:payments) do
      remove :contact_email
    end

    # Add order_id
    alter table(:payments) do
      add :order_id, :string
    end

    # copy the existing primary key to order_id (converting it to string)
    execute "UPDATE payments SET order_id = id"

    # Remove the old auto-generated id column
    alter table(:payments) do
      remove :id
    end

    # Set order_id as the primary key
    execute "ALTER TABLE payments ADD PRIMARY KEY (order_id)"

    # Create unique index on order_id
    create unique_index(:payments, [:order_id])

    # Drop the unique index on confirmation_code
    drop unique_index(:payments, [:confirmation_code])
  end
end
