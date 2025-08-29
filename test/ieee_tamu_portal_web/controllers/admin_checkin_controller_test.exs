defmodule IeeeTamuPortalWeb.AdminCheckinControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.{Repo}
  alias IeeeTamuPortal.Members.EventCheckin

  setup %{conn: conn} do
    # Simulate admin auth by setting the expected basic auth header.
    # The app uses AdminAuth plug; if it checks app config, you may need to
    # adjust this helper to satisfy the plug's expectations.
    conn =
      Plug.Conn.put_req_header(
        conn,
        "authorization",
        "Basic " <> Base.encode64("admin:test_password")
      )

    # Ensure defaults for settings
    registration_year_setting_fixture("2025")
    current_event_setting_fixture("test_event")

    {:ok, conn: conn}
  end

  test "GET /admin/check-in creates a check-in for the member", %{conn: conn} do
    member = confirmed_member_fixture()

    conn = get(conn, ~p"/admin/check-in", member_id: member.id)
    assert response(conn, 201) == "checked-in"

    checkins = Repo.all(EventCheckin)
    assert length(checkins) == 1
    [checkin] = checkins
    assert checkin.member_id == member.id
    assert checkin.event_name == "test_event"
    assert checkin.event_year == 2025
  end

  test "GET /admin/check-in is idempotent for the same member+event+year", %{conn: conn} do
    member = confirmed_member_fixture()

    conn1 = get(conn, ~p"/admin/check-in", member_id: member.id)
    assert response(conn1, 201) == "checked-in"

    conn2 = get(conn, ~p"/admin/check-in", member_id: member.id)
    assert response(conn1, 201) == "checked-in"

    count = Repo.aggregate(EventCheckin, :count)
    assert count == 1
  end

  test "GET /admin/check-in returns 400 when member param is missing", %{conn: conn} do
    conn = get(conn, ~p"/admin/check-in")
    assert json_response(conn, 400)["error"] == "missing_member_param"
  end

  test "GET /admin/check-in returns 422 for non-existent member id", %{conn: conn} do
    conn = get(conn, ~p"/admin/check-in", member_id: 999_999)
    assert %{"error" => "validation_error"} = json_response(conn, 422)
  end
end
