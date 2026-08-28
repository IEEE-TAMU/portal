defmodule IeeeTamuPortal.Services.FileStorageServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Services.FileStorageService

  setup do
    Req.Test.set_req_test_to_shared()

    original_s3 = Application.get_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload)

    Application.put_env(:ieee_tamu_portal, :s3_delete_req_opts,
      plug: {Req.Test, IeeeTamuPortal.S3Delete},
      retry: false
    )

    # The S3Delete success path logs at :info, which the test env suppresses.
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: :warning)
      Application.delete_env(:ieee_tamu_portal, :s3_delete_req_opts)
      Application.put_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload, original_s3)
    end)

    :ok
  end

  defp upload_entry(name) do
    %Phoenix.LiveView.UploadEntry{client_name: name, client_type: "application/pdf"}
  end

  describe "upload_resume/2" do
    test "creates a resume from an upload entry" do
      member = member_fixture()

      assert {:ok, resume} = FileStorageService.upload_resume(member, upload_entry("r.pdf"))
      assert resume.original_filename == "r.pdf"
      assert resume.key == "resumes/#{member.id}-#{member.email}.pdf"
    end

    test "creates a resume from plain params" do
      # Use a deterministic email — plain-param keys sanitize everything
      # except alphanumerics, @ and dots.
      member = member_fixture(%{email: "storage.test@tamu.edu"})

      assert {:ok, resume} =
               FileStorageService.upload_resume(member, %{client_name: "other.PDF"})

      assert resume.key == "resumes/#{member.id}-storage.test@tamu.edu.PDF"
    end
  end

  describe "generate_resume_key/2" do
    test "builds a key from an upload entry" do
      member = member_fixture()

      key = FileStorageService.generate_resume_key(member, upload_entry("r.pdf"))

      assert key == "resumes/#{member.id}-#{member.email}.pdf"
    end

    test "builds a key from plain params" do
      # Use a deterministic email — plain-param keys sanitize everything
      # except alphanumerics, @ and dots.
      member = member_fixture(%{email: "storage.test@tamu.edu"})

      key = FileStorageService.generate_resume_key(member, %{client_name: "r.docx"})

      assert key == "resumes/#{member.id}-storage.test@tamu.edu.docx"
    end
  end

  describe "get_resume_url/2" do
    test "returns a signed URL for a resume" do
      member = member_fixture()
      {:ok, resume} = FileStorageService.upload_resume(member, upload_entry("r.pdf"))

      assert {:ok, url} = FileStorageService.get_resume_url(resume)
      assert url =~ resume.key
      assert url =~ "X-Amz-Signature"
    end

    test "returns {:error, :configuration_missing} when S3 is unconfigured" do
      member = member_fixture()
      {:ok, resume} = FileStorageService.upload_resume(member, upload_entry("r.pdf"))

      Application.delete_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload)

      assert {:error, :configuration_missing} = FileStorageService.get_resume_url(resume)
    end
  end

  describe "delete_resume/1" do
    test "deletes the resume record and requests the object deletion" do
      member = member_fixture()
      {:ok, resume} = FileStorageService.upload_resume(member, upload_entry("r.pdf"))

      stub_s3_delete(204)

      log =
        capture_log([level: :info], fn ->
          assert {:ok, _deleted} = FileStorageService.delete_resume(resume)
          assert Repo.aggregate(IeeeTamuPortal.Members.Resume, :count, :id) == 0
          wait_for_s3_delete()
        end)

      assert log =~ "Deleted S3 object"
    end

    test "returns {:error, :not_found} when the record is already gone" do
      member = member_fixture()
      {:ok, resume} = FileStorageService.upload_resume(member, upload_entry("r.pdf"))

      capture_log(fn ->
        stub_s3_delete(204)

        assert {:ok, _} = FileStorageService.delete_resume(resume)
        wait_for_s3_delete()

        stub_s3_delete(204)

        assert {:error, :not_found} = FileStorageService.delete_resume(resume)
        wait_for_s3_delete()
      end)
    end
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
    Process.sleep(50)
  rescue
    RuntimeError ->
      Process.sleep(25)
      wait_for_s3_delete(attempts - 1)
  end
end
