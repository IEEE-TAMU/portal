defmodule IeeeTamuPortalWeb.Api.CalendarRenderingTest do
  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortal.Events.Event
  alias IeeeTamuPortalWeb.Api.CalendarRendering

  defp event!(attrs \\ %{}) do
    %Event{}
    |> Map.put(:uid, Map.get(attrs, :uid, Ecto.UUID.generate()))
    |> Map.put(:dtstart, Map.get(attrs, :dtstart, ~U[2025-01-01 10:00:00Z]))
    |> Map.put(:dtend, Map.get(attrs, :dtend, ~U[2025-01-01 11:00:00Z]))
    |> Map.put(:summary, Map.get(attrs, :summary, "Meeting"))
    |> Map.put(:description, Map.get(attrs, :description, "Weekly meeting"))
    |> Map.put(:location, Map.get(attrs, :location, "ZACH 100"))
    |> Map.put(:organizer, Map.get(attrs, :organizer, "IEEE TAMU"))
    |> Map.put(:rsvpable, Map.get(attrs, :rsvpable, true))
    |> Map.put(:inserted_at, ~U[2025-01-01 09:00:00Z])
    |> Map.put(:updated_at, ~U[2025-01-01 09:00:00Z])
  end

  defp render(events) do
    conn = build_conn()
    conn = CalendarRendering.render_ics(conn, events)

    {conn.status, get_resp_header(conn, "content-type"),
     get_resp_header(conn, "content-disposition"), conn.resp_body}
  end

  describe "render_ics/2" do
    test "returns a 200 ICS response with the expected headers" do
      {status, [ctype], [disposition], body} = render([event!()])

      assert status == 200
      assert String.starts_with?(ctype, "text/calendar")
      assert disposition == ~s(inline; filename="calendar.ics")
      assert String.contains?(body, "BEGIN:VCALENDAR")
      assert String.contains?(body, "END:VCALENDAR")
      assert String.contains?(body, "BEGIN:VEVENT")
      assert String.contains?(body, "END:VEVENT")
    end

    test "renders the event fields into the ICS payload" do
      {_status, _ctype, _disp, body} =
        render([
          event!(%{
            summary: "Public Event",
            location: "ZACH 200",
            description: "A long description"
          })
        ])

      assert String.contains?(body, "SUMMARY:Public Event")
      assert String.contains?(body, "LOCATION:ZACH 200")
      assert String.contains?(body, "DESCRIPTION:A long description")
    end

    test "renders multiple events" do
      {_status, _ctype, _disp, body} =
        render([
          event!(%{summary: "First"}),
          event!(%{summary: "Second"})
        ])

      assert length(String.split(body, "BEGIN:VEVENT")) - 1 == 2
      assert String.contains?(body, "SUMMARY:First")
      assert String.contains?(body, "SUMMARY:Second")
    end

    test "includes x-rsvp-url when the event is rsvpable" do
      {_status, _ctype, _disp, body} = render([event!(%{rsvpable: true, uid: "abc-123"})])
      assert String.contains?(body, "X-RSVP-URL:")
      assert String.contains?(body, "/members/registration?rsvp=abc-123")
    end

    test "omits x-rsvp-url when the event is not rsvpable" do
      {_status, _ctype, _disp, body} = render([event!(%{rsvpable: false})])
      refute String.contains?(body, "X-RSVP-URL:")
    end

    test "uses CRLF line endings per RFC 5545 (no lone LF)" do
      {_status, _ctype, _disp, body} = render([event!()])
      assert String.contains?(body, "\r\n")
      refute Regex.match?(~r/(^|[^\r])\n/, body)
    end

    test "folds lines longer than 75 octets per RFC 5545" do
      long_summary = String.duplicate("A", 200)
      {_status, _ctype, _disp, body} = render([event!(%{summary: long_summary})])

      lines = String.split(body, "\r\n")

      # Every emitted line must respect the 75-octet limit.
      assert Enum.all?(lines, fn line -> byte_size(line) <= 75 end)

      # The long summary must have been folded onto a continuation line
      # that begins with a single space.
      folded? =
        lines
        |> Enum.chunk_by(&String.starts_with?(&1, " "))
        |> Enum.any?(fn chunk -> length(chunk) > 1 and hd(chunk) != " " end)

      assert folded? or Enum.any?(lines, &String.starts_with?(&1, " "))
    end
  end
end
