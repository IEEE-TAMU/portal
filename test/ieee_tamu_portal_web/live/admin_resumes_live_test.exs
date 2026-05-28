defmodule IeeeTamuPortalWeb.AdminResumesLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]

  describe "Admin Resumes page" do
    test "requires admin basic auth", %{conn: conn} do
      conn = get(conn, ~p"/admin/resumes")
      assert conn.status == 401
    end

    test "renders page with admin auth", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/resumes")

      assert html =~ "Resumes"
      assert html =~ "Download member resumes as ZIP archives"
    end

    test "shows resume counts (all, full-time, internship)", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/resumes")

      assert html =~ "All Resumes"
      assert html =~ "Full-Time"
      assert html =~ "Internship"
    end

    test "download links are not shown when count is zero", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/resumes")

      refute html =~ "Download All"
      refute html =~ "Download Full-Time"
      refute html =~ "Download Internship"
    end
  end
end
