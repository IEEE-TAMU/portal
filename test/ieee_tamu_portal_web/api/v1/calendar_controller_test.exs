defmodule IeeeTamuPortalWeb.Api.V1.CalendarControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_api_auth_conn: 1]
  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Api

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

  defp admin_token do
    {:ok, {token, _key}} = Api.create_admin_api_key(%{"name" => "Test Admin Key"})
    token
  end

  describe "GET /api/v1/calendar (public)" do
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

    test "excludes private events", %{conn: conn} do
      _public = create_event!(%{summary: "Public Event", private: false})
      _private = create_event!(%{summary: "Private Event", private: true})

      conn = get(conn, ~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body
      assert String.contains?(body, "Public Event")
      refute String.contains?(body, "Private Event")
    end
  end

  describe "GET /api/v1/calendar (admin via Bearer token)" do
    test "includes private events with admin Bearer auth", %{conn: conn} do
      _public = create_event!(%{summary: "Public Event", private: false})
      _private = create_event!(%{summary: "Private Event", private: true})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> admin_api_auth_conn()
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body
      assert String.contains?(body, "Public Event")
      assert String.contains?(body, "Private Event")
    end
  end

  describe "GET /api/v1/calendar (admin via ?token= query param)" do
    test "includes private events with admin token query param", %{conn: conn} do
      _public = create_event!(%{summary: "Public Event", private: false})
      _private = create_event!(%{summary: "Private Event", private: true})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get("/api/v1/calendar?token=#{admin_token()}")

      assert conn.status == 200
      body = conn.resp_body
      assert String.contains?(body, "Public Event")
      assert String.contains?(body, "Private Event")
    end

    test "ignores invalid token query param and returns public events", %{conn: conn} do
      _public = create_event!(%{summary: "Public Event", private: false})
      _private = create_event!(%{summary: "Private Event", private: true})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get("/api/v1/calendar?token=invalid_bogus_token")

      assert conn.status == 200
      body = conn.resp_body
      assert String.contains?(body, "Public Event")
      refute String.contains?(body, "Private Event")
    end
  end
end
