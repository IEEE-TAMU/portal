defmodule IeeeTamuPortal.Repo.Migrations.CreateMemberInfos do
  use Ecto.Migration

  def change do
    create table(:member_infos) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :tshirt_size, :string, null: false
      add :uin, :integer, null: false
      add :preferred_name, :string
      add :phone_number, :string
      add :graduation_year, :integer, null: false
      add :major, :string, null: false
      add :major_other, :string
      add :gender, :string, null: false
      add :gender_other, :string
      add :age, :integer
      add :international_student, :boolean, default: false, null: false
      add :international_country, :string
      add :ieee_membership_number, :integer
      add :member_id, references(:members, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:member_infos, [:uin])
    create index(:member_infos, [:member_id])
  end
end
