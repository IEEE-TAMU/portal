defmodule IeeeTamuPortalWeb.AdminResumeZipController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.ResumeZipService

  def download(conn, _params) do
    case ResumeZipService.create_zip() do
      {:ok, zip_path} ->
        # Send the file
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", "attachment; filename=\"member_resumes.zip\"")
        |> send_file(200, zip_path)
        |> then(fn conn ->
          # Schedule cleanup after sending
          Task.start(fn ->
            # Give time for download to complete
            Process.sleep(1000)
            ResumeZipService.cleanup_zip(zip_path)
          end)

          conn
        end)

      {:error, :no_resumes_found} ->
        conn
        |> put_flash(:error, "No resumes found to download.")
        |> redirect(to: ~p"/admin")

      {:error, :already_creating} ->
        conn
        |> put_flash(:error, "Zip creation already in progress. Please try again in a moment.")
        |> redirect(to: ~p"/admin")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to create zip file: #{inspect(reason)}")
        |> redirect(to: ~p"/admin")
    end
  end
end
