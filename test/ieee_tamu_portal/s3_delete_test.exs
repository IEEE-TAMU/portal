defmodule IeeeTamuPortal.S3DeleteTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog

  alias IeeeTamuPortal.S3Delete
  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  @uri "https://test-bucket.s3.amazonaws.com/resumes/test.pdf"

  setup do
    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :s3_delete_req_opts,
      plug: {Req.Test, S3Delete},
      retry: false
    )

    # The success path logs at :info, which the test env suppresses.
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: :warning)
      Application.delete_env(:ieee_tamu_portal, :s3_delete_req_opts)
    end)

    :ok
  end

  test "logs success when the object is deleted" do
    Req.Test.expect(S3Delete, fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    log =
      capture_log(fn ->
        S3Delete.delete_object(S3Delete, @uri)
        wait_for_delete()
      end)

    assert log =~ "Deleted S3 object #{@uri}"
  end

  test "logs an error when the delete request fails" do
    Req.Test.expect(S3Delete, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/xml")
      |> Plug.Conn.resp(403, "AccessDenied")
    end)

    log =
      capture_log(fn ->
        S3Delete.delete_object(S3Delete, @uri)
        wait_for_delete()
      end)

    assert log =~ "S3 delete failed with status code: 403 for #{@uri}"
  end

  # The S3Delete GenServer handles the delete asynchronously; wait until the
  # stubbed request has been made before asserting on the captured log.
  defp wait_for_delete(attempts \\ 100)

  defp wait_for_delete(0), do: flunk("S3 delete request was never made")

  defp wait_for_delete(attempts) do
    Req.Test.verify!(S3Delete)

    # The stub is consumed before the GenServer logs, so give it a moment.
    Process.sleep(50)
  rescue
    RuntimeError ->
      Process.sleep(25)
      wait_for_delete(attempts - 1)
  end
end
