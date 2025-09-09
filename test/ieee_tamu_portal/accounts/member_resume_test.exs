defmodule IeeeTamuPortal.Accounts.MemberResumeTest do
  use IeeeTamuPortal.DataCase

  import IeeeTamuPortal.AccountsFixtures
  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.Members.Resume
  alias IeeeTamuPortal.Repo

  # Simulate a Phoenix.LiveView.UploadEntry minimal struct subset we rely on
  defp upload_entry(name) do
    %Phoenix.LiveView.UploadEntry{client_name: name, client_type: "application/pdf"}
  end

  test "put_resume/2 creates a resume for member" do
    member = member_fixture()
    entry = upload_entry("first.pdf")

    assert {:ok, updated_member} = Member.put_resume(member, entry)
    assert %Resume{} = updated_member.resume
    assert updated_member.resume.original_filename == "first.pdf"

    # Only one resume row exists
    assert Repo.aggregate(Resume, :count, :id) == 1
  end

  test "put_resume/2 replaces existing resume without creating duplicates" do
    member = member_fixture()

    assert {:ok, member} = Member.put_resume(member, upload_entry("one.pdf"))
    first_resume_id = member.resume.id

    # Reload to simulate separate request cycle (with preload)
    member = Repo.preload(member, :resume)
    assert {:ok, member} = Member.put_resume(member, upload_entry("two.pdf"))

    # Resume updated in place
    assert member.resume.original_filename == "two.pdf"
    assert member.resume.id == first_resume_id

    # Still only one resume in DB
    assert Repo.aggregate(Resume, :count, :id) == 1
  end

  test "put_resume/2 handles call when resume not preloaded by fetching existing" do
    member = member_fixture()
    assert {:ok, member} = Member.put_resume(member, upload_entry("initial.pdf"))

    # Drop the preload by constructing a bare struct (simulate code path w/out :resume)
    member_no_preload = %IeeeTamuPortal.Accounts.Member{id: member.id, email: member.email}

    assert {:ok, member_after} = Member.put_resume(member_no_preload, upload_entry("updated.pdf"))

    assert member_after.resume.original_filename == "updated.pdf"
    # Only one resume still
    assert Repo.aggregate(Resume, :count, :id) == 1
  end
end
