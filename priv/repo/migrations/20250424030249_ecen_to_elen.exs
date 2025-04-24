defmodule IeeeTamuPortal.Repo.Migrations.EcenToElen do
  use Ecto.Migration

  # Up:
  # - "ECEN" -> "ELEN" in major
  # - "Other" + major_other = "ELEN" → major = "ELEN", major_other = NULL
  #
  # Down:
  # - "ELEN" -> "Other" with major_other = "ELEN" if it came from the second case

  def up do
    execute("""
    UPDATE member_infos
    SET major = 'ELEN'
    WHERE major = 'ECEN'
    """)

    execute("""
    UPDATE member_infos
    SET major = 'ELEN',
        major_other = NULL
    WHERE major = 'Other'
      AND major_other = 'ELEN'
    """)
  end

  def down do
    execute("""
    UPDATE member_infos
    SET major = 'Other',
        major_other = 'ELEN'
    WHERE major = 'ELEN'
    """)
  end
end
