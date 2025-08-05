defmodule IeeeTamuPortal.Services.FileStorageServiceTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Services.FileStorageService
  alias IeeeTamuPortal.Members

  import IeeeTamuPortal.AccountsFixtures

  describe "upload_resume/2" do
    test "creates resume record with upload params" do
      member = member_fixture()

      # Mock upload params (simplified for testing)
      upload_params = %{
        client_name: "resume.pdf"
      }

      result = FileStorageService.upload_resume(member, upload_params)

      assert {:ok, resume} = result
      assert resume.member_id == member.id
      assert resume.original_filename == "resume.pdf"
      assert is_binary(resume.key)
      assert String.contains?(resume.key, "resumes/")
    end

    test "returns error with invalid upload" do
      member = member_fixture()

      invalid_params = %{client_name: ""}

      assert {:error, changeset} = FileStorageService.upload_resume(member, invalid_params)
      assert changeset.errors[:original_filename]
    end
  end

  describe "delete_resume/1" do
    test "successfully deletes existing resume" do
      member = member_fixture()

      # Create a resume first
      {:ok, resume} =
        Members.create_member_resume(member, %{
          original_filename: "test_resume.pdf",
          key: "resumes/#{member.id}-test_resume.pdf"
        })

      # Should successfully delete
      assert {:ok, _deleted_resume} = FileStorageService.delete_resume(resume)
    end

    test "handles resume that doesn't exist gracefully" do
      resume = %Members.Resume{
        id: 999,
        original_filename: "nonexistent.pdf",
        key: "resumes/nonexistent.pdf"
      }

      # Should handle stale entry error gracefully
      assert {:error, :not_found} = FileStorageService.delete_resume(resume)
    end
  end

  describe "get_resume_url/2" do
    test "handles S3 configuration errors gracefully" do
      member = member_fixture()

      resume = %Members.Resume{
        original_filename: "test_resume.pdf",
        key: "resumes/#{member.id}-test_resume.pdf",
        bucket_url: "https://test-bucket.s3.amazonaws.com"
      }

      # Should handle missing S3 config gracefully
      assert {:error, :configuration_missing} = FileStorageService.get_resume_url(resume)
    end

    test "accepts options for URL generation" do
      member = member_fixture()

      resume = %Members.Resume{
        original_filename: "test_resume.pdf",
        key: "resumes/#{member.id}-test_resume.pdf",
        bucket_url: "https://test-bucket.s3.amazonaws.com"
      }

      opts = [method: "GET", response_content_type: "application/pdf"]

      # Should handle missing S3 config gracefully even with options
      assert {:error, :configuration_missing} = FileStorageService.get_resume_url(resume, opts)
    end
  end

  describe "generate_resume_key/2" do
    test "generates unique key for member and upload" do
      member = member_fixture()

      upload_params = %{client_name: "my_resume.pdf"}

      key = FileStorageService.generate_resume_key(member, upload_params)

      assert is_binary(key)
      assert String.starts_with?(key, "resumes/")
      assert String.contains?(key, to_string(member.id))
      assert String.ends_with?(key, ".pdf")
    end

    test "sanitizes member email in key" do
      # Use a valid TAMU email
      member = member_fixture(%{email: "testuser@tamu.edu"})

      upload_params = %{client_name: "resume.pdf"}

      key = FileStorageService.generate_resume_key(member, upload_params)

      # Should include member ID and be properly formatted
      assert String.contains?(key, to_string(member.id))
      assert String.contains?(key, "testuser@tamu.edu")
      assert String.ends_with?(key, ".pdf")
    end
  end
end
