defmodule IeeeTamuPortal.Repo.Migrations.CreateOidcClients do
  use Ecto.Migration

  def change do
    create table(:oidc_clients) do
      add :name, :string, null: false
      add :client_id, :string, null: false
      add :client_secret_hash, :binary, null: false
      add :secret_prefix, :string
      add :redirect_uris, :text, null: false
      add :scopes, :string, null: false, default: "openid profile email role"
      add :enabled, :boolean, null: false, default: true
      add :last_used_at, :utc_datetime
      add :created_by_id, references(:members, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oidc_clients, [:client_id])
  end
end
