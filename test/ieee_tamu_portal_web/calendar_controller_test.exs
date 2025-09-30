defmodule IeeeTamuPortalWeb.CalendarControllerTest do
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

  describe "RFC 5545 compliance tests" do
    test "calendar output uses CRLF line endings", %{conn: conn} do
      _e = create_event!()

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body

      # Check that we have CRLF line endings
      assert String.contains?(body, "\r\n"),
             "ICS output should use CRLF (\\r\\n) line endings per RFC 5545"
    end

    test "all events have DTSTAMP property", %{conn: conn} do
      _e1 = create_event!()
      _e2 = create_event!(%{summary: "Workshop"})

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body

      # Count events and DTSTAMP occurrences
      event_count =
        body |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "BEGIN:VEVENT"))

      dtstamp_count =
        body |> String.split("\n") |> Enum.count(&String.starts_with?(&1, "DTSTAMP:"))

      assert dtstamp_count >= event_count, "Each VEVENT must have a DTSTAMP property per RFC 5545"
    end

    test "no lines exceed 75 characters", %{conn: conn} do
      # Create event with long description to test line folding
      _e =
        create_event!(%{
          summary:
            "Very Long Meeting Title That Might Exceed The 75 Character Limit For ICS Lines",
          description:
            "This is a very long description that definitely exceeds the 75 character limit specified in RFC 5545 for iCalendar content lines and should be properly folded",
          location: "A Very Long Location Name That Could Potentially Cause Line Length Issues"
        })

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body

      # Check line lengths (accounting for CRLF)
      lines = String.split(body, "\r\n")
      long_lines = Enum.filter(lines, &(String.length(&1) > 75))

      if length(long_lines) > 0 do
        flunk(
          "Found #{length(long_lines)} lines longer than 75 characters:\n" <>
            Enum.map_join(
              long_lines,
              "\n",
              &"  #{String.length(&1)} chars: #{String.slice(&1, 0, 50)}..."
            )
        )
      end
    end

    test "calendar structure is valid", %{conn: conn} do
      _e = create_event!()

      conn =
        conn
        |> put_req_header("accept", "text/calendar")
        |> get(~p"/api/v1/calendar")

      assert conn.status == 200
      body = conn.resp_body

      # Basic structure validation
      assert String.contains?(body, "BEGIN:VCALENDAR")
      assert String.contains?(body, "END:VCALENDAR")
      assert String.contains?(body, "VERSION:2.0")
      assert String.contains?(body, "PRODID:")
      assert String.contains?(body, "BEGIN:VEVENT")
      assert String.contains?(body, "END:VEVENT")
    end
  end
end
