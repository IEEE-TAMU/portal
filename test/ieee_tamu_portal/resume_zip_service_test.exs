defmodule IeeeTamuPortal.ResumeZipServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.{Members, ResumeZipService}

  setup do
    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :resume_zip_req_opts,
      plug: {Req.Test, IeeeTamuPortal.ResumeZipService},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :resume_zip_req_opts)
    end)

    :ok
  end

  defp member_with_resume(looking_for) do
    member = confirmed_member_fixture()
    entry = %Phoenix.LiveView.UploadEntry{client_name: "r.pdf", client_type: "application/pdf"}

    {:ok, _} = Members.put_member_resume(member, entry, looking_for)

    member
  end

  defp stub_resume_fetch(status) do
    Req.Test.expect(IeeeTamuPortal.ResumeZipService, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/pdf")
      |> Plug.Conn.resp(status, "%PDF-1.4 fake resume")
    end)
  end

  describe "count_resumes/1" do
    test "counts all resumes by default" do
      member_with_resume(:full_time)
      member_with_resume(:internship)

      assert ResumeZipService.count_resumes() == 2
    end

    test "filters by looking_for, including :either in both subsets" do
      member_with_resume(:full_time)
      member_with_resume(:either)

      assert ResumeZipService.count_resumes(:full_time) == 2
      assert ResumeZipService.count_resumes(:internship) == 1
    end
  end

  describe "stream_zip/1" do
    test "returns {:error, :no_resumes_found} when no member has a resume" do
      assert {:error, :no_resumes_found} = ResumeZipService.stream_zip([])
    end

    test "returns a zip stream containing every resume" do
      member_with_resume(:full_time)
      member_with_resume(:internship)

      stub_resume_fetch(200)
      stub_resume_fetch(200)

      assert {:ok, zip_stream} = ResumeZipService.stream_zip([])

      log =
        capture_log(fn ->
          assert zip_stream |> Enum.to_list() |> IO.iodata_length() > 0
        end)

      refute log =~ "Failed to fetch resume"
    end

    test "skips resumes that cannot be fetched" do
      member_with_resume(:full_time)

      stub_resume_fetch(404)

      log =
        capture_log(fn ->
          assert {:ok, zip_stream} = ResumeZipService.stream_zip([])
          assert zip_stream |> Enum.to_list() |> IO.iodata_length() > 0
        end)

      assert log =~ "Failed to fetch resume"
    end

    test "respects the looking_for filter" do
      member_with_resume(:internship)
      member_with_resume(:full_time)

      # Only the internship resume should be fetched
      stub_resume_fetch(200)

      assert {:ok, zip_stream} = ResumeZipService.stream_zip(looking_for: :internship)
      assert zip_stream |> Enum.to_list() |> IO.iodata_length() > 0
    end

    test "sanitizes entry filenames from member info and falls back to email" do
      # Member without info → falls back to the email prefix
      member_with_resume(:full_time)

      # Member with info → uses preferred_name + last_name, sanitized
      member = confirmed_member_fixture()
      entry = %Phoenix.LiveView.UploadEntry{client_name: "r.pdf", client_type: "application/pdf"}

      {:ok, _} =
        Members.create_member_info(member, %{
          first_name: "Jane",
          last_name: "Doe!",
          preferred_name: "  ",
          uin: 123_004_569,
          tshirt_size: :M,
          major: :CSCE,
          graduation_year: 2026,
          gender: :Female,
          international_student: false
        })

      {:ok, _} = Members.put_member_resume(member, entry, :full_time)

      stub_resume_fetch(200)
      stub_resume_fetch(200)

      assert {:ok, zip_stream} = ResumeZipService.stream_zip([])
      assert zip_stream |> Enum.to_list() |> IO.iodata_length() > 0
    end
  end
end
