defmodule IeeeTamuPortal.Repo.Migrations.AddUniqueIndexOnResumesMemberId do
  use Ecto.Migration

  def up do
    # MySQL/MariaDB compatible duplicate cleanup: keep the most recently updated (falling back to highest id)
    # Delete any resume older than another resume for the same member.
    execute """
    DELETE r1 FROM resumes r1
    JOIN resumes r2
      ON r1.member_id = r2.member_id
     AND (
          r1.updated_at < r2.updated_at OR
          (r1.updated_at = r2.updated_at AND r1.id < r2.id)
         );
    """
  end
end
