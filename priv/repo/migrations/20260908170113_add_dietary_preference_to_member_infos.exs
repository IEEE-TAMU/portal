defmodule IeeeTamuPortal.Repo.Migrations.AddDietaryPreferenceToMemberInfos do
  use Ecto.Migration

  def change do
    alter table(:member_infos) do
      add :dietary_preference, :string, null: false, default: "None"
    end
  end
end
