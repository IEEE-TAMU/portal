defmodule IeeeTamuPortal.Repo.Migrations.TrimSpacesFromNames do
  use Ecto.Migration

  def up do
    execute("""
      UPDATE member_infos
      SET first_name = TRIM(first_name),
          last_name = TRIM(last_name),
          preferred_name = TRIM(preferred_name),
          major_other = TRIM(major_other),
          gender_other = TRIM(gender_other),
          international_country = TRIM(international_country)
      WHERE first_name LIKE ' %'
         OR last_name LIKE ' %'
         OR preferred_name LIKE ' %'
         OR major_other LIKE ' %'
         OR gender_other LIKE ' %'
         OR international_country LIKE ' %'
         OR first_name LIKE '% '
         OR last_name LIKE '% '
         OR preferred_name LIKE '% '
         OR major_other LIKE '% '
         OR gender_other LIKE '% '
         OR international_country LIKE '% '
    """)

    execute("""
      UPDATE payments
      SET name = TRIM(name)
      WHERE name LIKE ' %' OR name LIKE '% '
    """)
  end

  def down do
    :ok
  end
end
