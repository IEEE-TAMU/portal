defmodule IeeeTamuPortalWeb.Upload.SimpleS3UploadTest do
  use ExUnit.Case, async: true

  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  describe "bucket_url/0" do
    test "returns configured bucket URL" do
      assert SimpleS3Upload.bucket_url() =~ "test-bucket.s3.amazonaws.com"
    end
  end

  describe "sign/1" do
    test "returns a signed URL" do
      assert {:ok, url} = SimpleS3Upload.sign(method: "GET", key: "test.pdf")
      assert is_binary(url)
      assert url =~ "test-bucket.s3.amazonaws.com"
      assert url =~ "test.pdf"
    end

    test "works with PUT method" do
      assert {:ok, url} = SimpleS3Upload.sign(method: "PUT", key: "resume.pdf")
      assert is_binary(url)
      assert url =~ "resume.pdf"
    end

    test "works with DELETE method and uri" do
      assert {:ok, url} =
               SimpleS3Upload.sign(
                 method: "DELETE",
                 uri: "https://test-bucket.s3.amazonaws.com/resume.pdf"
               )

      assert is_binary(url)
    end
  end
end
