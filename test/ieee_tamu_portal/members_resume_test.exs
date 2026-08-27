defmodule IeeeTamuPortal.MembersResumeTest do
  use IeeeTamuPortal.DataCase

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Members.Resume
  alias IeeeTamuPortal.Repo

  setup do
    # Route S3Delete's HTTP calls through Req.Test so deletes can be stubbed
    # instead of hitting the real bucket. Tests are not async, so the stubs
    # are shared with the S3Delete GenServer process.
    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :s3_delete_req_opts,
      plug: {Req.Test, IeeeTamuPortal.S3Delete},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :s3_delete_req_opts)
    end)

    :ok
  end

  # Simulate a Phoenix.LiveView.UploadEntry minimal struct subset
  defp upload_entry(name) do
    %Phoenix.LiveView.UploadEntry{client_name: name, client_type: "application/pdf"}
  end

  defp stub_s3_delete(status) do
    Req.Test.expect(IeeeTamuPortal.S3Delete, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(status, "stubbed")
    end)
  end

  # The S3Delete GenServer handles the delete asynchronously; wait until the
  # stubbed request has been made before asserting on the captured log.
  defp wait_for_s3_delete(attempts \\ 100)

  defp wait_for_s3_delete(0), do: flunk("S3 delete request was never made")

  defp wait_for_s3_delete(attempts) do
    Req.Test.verify!(IeeeTamuPortal.S3Delete)
  rescue
    RuntimeError ->
      Process.sleep(25)
      wait_for_s3_delete(attempts - 1)
  end

  describe "put_member_resume/2" do
    test "creates a resume for member" do
      member = member_fixture()
      entry = upload_entry("first.pdf")

      assert {:ok, updated_member} = Members.put_member_resume(member, entry)
      assert %Resume{} = updated_member.resume
      assert updated_member.resume.original_filename == "first.pdf"
      assert Repo.aggregate(Resume, :count, :id) == 1
    end

    test "replaces existing resume without creating duplicates" do
      member = member_fixture()

      assert {:ok, member} = Members.put_member_resume(member, upload_entry("one.pdf"))
      first_resume_id = member.resume.id

      member = Repo.preload(member, :resume)
      assert {:ok, member} = Members.put_member_resume(member, upload_entry("two.pdf"))

      assert member.resume.original_filename == "two.pdf"
      assert member.resume.id == first_resume_id
      assert Repo.aggregate(Resume, :count, :id) == 1
    end

    test "handles call when resume not preloaded by fetching existing" do
      member = member_fixture()
      assert {:ok, member} = Members.put_member_resume(member, upload_entry("initial.pdf"))

      member_no_preload = %IeeeTamuPortal.Accounts.Member{id: member.id, email: member.email}

      assert {:ok, member_after} =
               Members.put_member_resume(member_no_preload, upload_entry("updated.pdf"))

      assert member_after.resume.original_filename == "updated.pdf"
      assert Repo.aggregate(Resume, :count, :id) == 1
    end
  end

  describe "put_member_resume/3 with looking_for" do
    test "defaults to :either" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry)
      assert member.resume.looking_for == :either
    end

    test "accepts atom looking_for" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, :internship)
      assert member.resume.looking_for == :internship
    end

    test "accepts \"Full-Time\" string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "Full-Time")
      assert member.resume.looking_for == :full_time
    end

    test "accepts \"Internship\" string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "Internship")
      assert member.resume.looking_for == :internship
    end

    test "accepts \"Either\" string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "Either")
      assert member.resume.looking_for == :either
    end

    test "accepts \"full_time\" lowercase string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "full_time")
      assert member.resume.looking_for == :full_time
    end

    test "accepts \"internship\" lowercase string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "internship")
      assert member.resume.looking_for == :internship
    end

    test "accepts \"either\" lowercase string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "either")
      assert member.resume.looking_for == :either
    end

    test "defaults to :either for unrecognized string" do
      member = member_fixture()
      entry = upload_entry("resume.pdf")

      {:ok, member} = Members.put_member_resume(member, entry, "unknown")
      assert member.resume.looking_for == :either
    end
  end

  describe "delete_member_resume/1" do
    test "returns {:ok, member} when member has no resume" do
      member = member_fixture()

      assert {:ok, returned} = Members.delete_member_resume(member)
      assert returned.id == member.id
      assert returned.resume == nil
    end

    test "deletes existing resume and returns member with resume nil" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      stub_s3_delete(403)

      log =
        capture_log(fn ->
          assert {:ok, returned} = Members.delete_member_resume(member)
          assert returned.resume == nil
          refute Repo.get(Resume, resume.id)
          wait_for_s3_delete()
        end)

      assert log =~ "S3 delete failed with status code: 403"
    end

    test "handles member with resume not preloaded" do
      member = member_fixture()

      Repo.insert!(%Resume{
        member_id: member.id,
        original_filename: "test.pdf",
        key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
      })

      # member has resume not loaded
      stub_s3_delete(403)

      log =
        capture_log(fn ->
          assert {:ok, returned} = Members.delete_member_resume(member)
          assert returned.resume == nil
          assert Repo.aggregate(Resume, :count, :id) == 0
          wait_for_s3_delete()
        end)

      assert log =~ "S3 delete failed with status code: 403"
    end
  end

  describe "update_resume_looking_for/2" do
    test "returns {:ok, member} when member has no resume" do
      member = member_fixture()

      assert {:ok, returned} = Members.update_resume_looking_for(member, :full_time)
      assert returned.id == member.id
      assert returned.resume == nil
    end

    test "updates looking_for on existing resume" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf",
          looking_for: :either
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, :internship)
      assert updated.resume.looking_for == :internship

      refetched = Repo.get(Resume, resume.id)
      assert refetched.looking_for == :internship
    end

    test "handles \"Full-Time\" string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "Full-Time")
      assert updated.resume.looking_for == :full_time
    end

    test "handles \"Internship\" string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "Internship")
      assert updated.resume.looking_for == :internship
    end

    test "handles \"Either\" string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "Either")
      assert updated.resume.looking_for == :either
    end

    test "handles \"full_time\" lowercase string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "full_time")
      assert updated.resume.looking_for == :full_time
    end

    test "handles \"internship\" lowercase string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "internship")
      assert updated.resume.looking_for == :internship
    end

    test "handles \"either\" lowercase string" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "either")
      assert updated.resume.looking_for == :either
    end

    test "defaults to :either for unrecognized looking_for" do
      member = member_fixture()

      resume =
        Repo.insert!(%Resume{
          member_id: member.id,
          original_filename: "test.pdf",
          key: "uploads/resumes/test-#{System.unique_integer()}.pdf"
        })

      member = %{member | resume: resume}

      {:ok, updated} = Members.update_resume_looking_for(member, "garbage")
      assert updated.resume.looking_for == :either
    end
  end
end
