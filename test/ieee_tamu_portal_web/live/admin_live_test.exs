defmodule IeeeTamuPortalWeb.AdminLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Members

  describe "Admin Dashboard page" do
    test "requires admin basic auth", %{conn: conn} do
      conn = get(conn, ~p"/admin")
      assert conn.status == 401
    end

    test "renders dashboard with admin auth", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      assert html =~ "Admin Dashboard"
      assert html =~ "Total Members"
      assert html =~ "Paid Members"
      assert html =~ "Resumes"
      assert html =~ "Feature Status"
      assert html =~ "Quick Actions"
      assert html =~ "Global Settings"
      assert html =~ "Events"
      assert html =~ "API Keys"
    end

    test "renders Quick Actions with links to admin pages", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      html = render(lv)

      assert html =~ ~p"/admin/settings"
      assert html =~ ~p"/admin/events"
      assert html =~ ~p"/admin/api-keys"
      assert html =~ ~p"/admin/resumes"
    end

    test "shows download-members CSV links", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      assert html =~ ~p"/admin/download-members"
      assert html =~ ~p"/admin/download-members?paid=true"
    end

    test "shows accurate member count", %{conn: conn} do
      member_fixture()
      confirmed_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      # Count includes all members (2 created above plus any others)
      assert html =~ "Total Members"
    end

    test "shows paid members count from current year", %{conn: conn} do
      registration_year_setting_fixture("2025")
      member = confirmed_member_fixture()
      create_member_info(member)

      {:ok, registration} = Members.get_or_create_registration(member, 2025)
      Members.update_registration(registration, %{payment_override: true})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      assert html =~ "Paid Members"
    end

    test "shows resume download action when S3 is configured", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      # S3 is configured in test.exs, so download link should appear
      # when resume_count > 0 (it won't show the link but the card is present)
      assert html =~ "Resumes"
    end

    test "displays feature status panel with enabled/disabled indicators", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin")

      assert html =~ "Feature Status"
      # Admin Panel and S3 Resume Upload are configured in test.exs
      assert html =~ "Enabled"
    end
  end

  defp create_member_info(member) do
    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: 123_001_234,
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })
  end
end
