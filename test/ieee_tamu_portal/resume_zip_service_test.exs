defmodule IeeeTamuPortal.ResumeZipServiceTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.ResumeZipService

  test "count_resumes/0 returns count of members with resumes" do
    # Should return 0 when no members have resumes
    assert ResumeZipService.count_resumes() == 0
  end

  test "stream_zip/0 returns error when no resumes found" do
    # Should return error when no resumes are available
    assert {:error, :no_resumes_found} = ResumeZipService.stream_zip()
  end
end
