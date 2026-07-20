defmodule IeeeTamuPortalWeb.Api.V1.AdminCalendarControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_api_auth_conn: 1]
  alias IeeeTamuPortal.Events

  defp create_event!(attrs \\ %{}) do
    base = %{
      dtstart: DateTime.utc_now() |> DateTime.truncate(:second),
      dtend: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
      summary: "Meeting",
      description: "Weekly meeting",
      location: "ZACH 100",
      organizer: "IEEE TAMU"
    }

    {:ok, event} = Events.create_event(Map.merge(base, attrs))
    event
  end

  describe "GET /api/v1/admin/calendar" do
    test "returns 401 without auth header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/admin/calendar")

      assert conn.status == 401
    end

    test "returns 200 with admin auth and includes private events in ICS", %{conn: conn} do
      _public = create_event!(%{summary: "Public Event", private: false})
      _private = create_event!(%{summary: "Private Event", private: true})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> admin_api_auth_conn()
        |> get(~p"/api/v1/admin/calendar")

      assert conn.status == 200
      body = conn.resp_body
      assert String.contains?(body, "Public Event")
      assert String.contains?(body, "Private Event")
    end
  end
end
