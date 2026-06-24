defmodule IeeeTamuPortalWeb.Api.V1.StatsControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.MembersFixtures
  import IeeeTamuPortal.SettingsFixtures

  describe "GET /api/v1/stats/paid-members" do
    test "returns paid member count and current year by default", %{conn: conn} do
      year = "2025"
      registration_year_setting_fixture(year)
      _paid_member = payment_fixture()

      conn = get(conn, ~p"/api/v1/stats/paid-members")

      assert %{
               "count" => count,
               "year" => 2025
             } = json_response(conn, 200)

      assert is_integer(count)
      assert count >= 1
    end

    test "returns zero when no paid members exist", %{conn: conn} do
      year = "2025"
      registration_year_setting_fixture(year)

      conn = get(conn, ~p"/api/v1/stats/paid-members")

      assert json_response(conn, 200) == %{"count" => 0, "year" => 2025}
    end

    test "uses the year query parameter when provided", %{conn: conn} do
      registration_year_setting_fixture("2025")

      conn = get(conn, ~p"/api/v1/stats/paid-members?year=2023")

      assert json_response(conn, 200) == %{"count" => 0, "year" => 2023}
    end

    test "does not require authentication", %{conn: conn} do
      registration_year_setting_fixture("2025")

      conn = get(conn, ~p"/api/v1/stats/paid-members")

      assert conn.status == 200
    end

    test "returns correct content type", %{conn: conn} do
      registration_year_setting_fixture("2025")

      conn = get(conn, ~p"/api/v1/stats/paid-members")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end
end
