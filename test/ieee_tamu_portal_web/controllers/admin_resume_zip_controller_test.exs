defmodule IeeeTamuPortalWeb.AdminResumeZipControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]

  test "requires admin auth", %{conn: conn} do
    conn = get(conn, ~p"/admin/download-resumes")
    assert conn.status == 401
  end

  test "redirects when S3 is not configured", %{conn: conn} do
    original = Application.get_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload)

    Application.put_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload,
      region: nil,
      access_key_id: nil,
      secret_access_key: nil,
      url: nil
    )

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload)
      else
        Application.put_env(:ieee_tamu_portal, IeeeTamuPortalWeb.Upload.SimpleS3Upload, original)
      end
    end)

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-resumes")

    assert redirected_to(conn) == ~p"/admin"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
             "Resume upload service is not configured"
  end

  test "with S3 configured and no resumes redirects with error", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-resumes")

    assert redirected_to(conn) == ~p"/admin"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No resumes found"
  end
end
