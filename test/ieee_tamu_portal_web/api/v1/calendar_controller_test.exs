defmodule IeeeTamuPortalWeb.Api.V1.CalendarControllerTest do
  use IeeeTamuPortalWeb.ConnCase

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

  describe "GET /api/v1/calendar" do
    test "returns text/calendar content type and ICS payload", %{conn: conn} do
      _e1 = create_event!()
      _e2 = create_event!(%{summary: "Workshop", location: "ZACH 200"})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      [ctype] = get_resp_header(conn, "content-type")
      assert String.starts_with?(ctype, "text/calendar")

      body = conn.resp_body
      assert is_binary(body)
      assert String.contains?(body, "BEGIN:VCALENDAR")
      assert String.contains?(body, "END:VCALENDAR")
      assert String.contains?(body, "BEGIN:VEVENT")
      assert String.contains?(body, "SUMMARY:")
    end

    test "works without Accept header (still returns ICS)", %{conn: conn} do
      _e = create_event!()

      conn = get(conn, ~p"/api/v1/calendar")

      assert conn.status == 200
      [ctype] = get_resp_header(conn, "content-type")
      assert String.starts_with?(ctype, "text/calendar")
    end
  end
end
