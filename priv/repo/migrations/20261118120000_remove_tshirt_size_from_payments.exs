defmodule IeeeTamuPortal.Repo.Migrations.RemoveTshirtSizeFromPayments do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      remove :tshirt_size, :string
    end
  end
end
