defmodule IeeeTamuPortalWeb.AdminCheckinLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.{Members, Settings}

  setup do
    registration_year_setting_fixture("2025")
    current_event_setting_fixture("general_meeting")
    :ok
  end

  describe "admin auth requirement" do
    test "requires admin basic auth", %{conn: conn} do
      conn = get(conn, ~p"/admin/checkin")
      assert conn.status == 401
    end
  end

  describe "Admin Checkin page" do
    test "renders the check-in page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Check-in"
      assert html =~ "Event Controls"
    end

    test "shows export section with current year", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Export Check-ins"
      assert html =~ "2025"
    end

    test "shows event controls with start event form when not scanning", %{conn: conn} do
      Settings.stop_current_event()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Start Event"
    end

    test "shows stop event button when scanning is enabled", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Stop Event"
    end

    test "download CSV link is present", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Download CSV"
      assert html =~ ~p"/admin/download-checkins"
    end

    test "start scanner button is present when scanning enabled", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      assert html =~ "Start Scanner"
    end
  end

  describe "event control operations" do
    test "set event updates current event", %{conn: conn} do
      Settings.stop_current_event()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      lv
      |> element("form[phx-submit=set_event]")
      |> render_submit(%{"event_name" => "test_event"})

      html = render(lv)
      assert html =~ "Stop Event"
      assert Settings.get_current_event!() == "test_event"
    end

    test "stop event disables scanning", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      lv
      |> element("button", "Stop Event")
      |> render_click()

      html = render(lv)
      assert html =~ "Start Event"
    end
  end

  describe "QR scan events" do
    test "handles unrecognized QR content", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      lv
      |> element("button", "Stop Event")
      |> render_click()

      html = render(lv)

      # When scanning is disabled, start scanner should be hidden
      refute html =~ "Start Scanner"
    end

    test "handles QR scanned event with invalid content", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      render_hook(lv, "qr_scanned", %{"content" => "invalid-content"})

      html = render(lv)
      assert html =~ "Unrecognized QR"
    end

    test "handles QR scanned event with valid content", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      qr_content = "https://example.com/admin/check-in?member_id=#{member.id}"

      render_hook(lv, "qr_scanned", %{"content" => qr_content})

      html = render(lv)
      assert html =~ "Scanning member #{member.id}..."
    end

    test "handles checkin response with success", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      render_hook(lv, "checkin_response", %{"ok" => true, "member_id" => "123"})

      html = render(lv)
      assert html =~ "Checked In"
    end

    test "handles checkin response with failure", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      render_hook(lv, "checkin_response", %{"ok" => false, "member_id" => "456"})

      html = render(lv)
      assert html =~ "Failed to check in member 456"
    end

    test "restart resets scanner state", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      render_hook(lv, "qr_scanned", %{"content" => "invalid"})

      render_hook(lv, "restart", %{})

      html = render(lv)
      assert html =~ "Scanner reset"
    end
  end

  describe "event selection for export" do
    test "select event updates selected_event", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      render_hook(lv, "select_event", %{"event_name" => "special_meeting"})

      html = render(lv)
      assert html =~ ~p"/admin/download-checkins?event_name=special_meeting"
    end
  end

  describe "PubSub check-in info" do
    test "handles member_checked_in info message", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/checkin")

      send(lv.pid, {:member_checked_in, 123})

      html = render(lv)
      assert html =~ "Server confirmed check-in"
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
