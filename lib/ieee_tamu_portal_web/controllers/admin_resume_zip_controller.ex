defmodule IeeeTamuPortalWeb.AdminResumeZipController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.ResumeZipService

  def download(conn, _params) do
    case ResumeZipService.stream_zip() do
      {:ok, zip_stream} ->
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"ieee_tamu_resumes.zip\""
        )
        |> send_chunked(200)
        |> stream_zip_data(zip_stream)

      {:error, :no_resumes_found} ->
        conn
        |> put_flash(:error, "No resumes found to download.")
        |> redirect(to: ~p"/admin")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to create zip file: #{inspect(reason)}")
        |> redirect(to: ~p"/admin")
    end
  end

  defp stream_zip_data(conn, zip_stream) do
    try do
      Enum.reduce_while(zip_stream, conn, fn chunk, acc_conn ->
        case Plug.Conn.chunk(acc_conn, chunk) do
          {:ok, new_conn} -> {:cont, new_conn}
          {:error, _reason} -> {:halt, acc_conn}
        end
      end)
    rescue
      error ->
        require Logger
        Logger.error("Error streaming zip data: #{inspect(error)}")
        conn
    end
  end
end
