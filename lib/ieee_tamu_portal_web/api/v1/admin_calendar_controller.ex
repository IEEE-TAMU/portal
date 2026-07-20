defmodule IeeeTamuPortalWeb.Api.V1.AdminCalendarController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Events

  tags ["calendar"]

  admin_operation :index,
    summary: "Admin iCalendar feed (includes private events)",
    description: "Returns an iCalendar (ICS) feed of all events, including private ones. Requires admin API key.",
    responses: [
      ok: {"ICS feed (all events)", "text/calendar", %OpenApiSpex.Schema{type: :string}}
    ] do
    fn conn, _params, _api_key ->
      events = Events.list_events(include_private: true)

      ics_events =
        for e <- events do
          %ICalendar.Event{}
          |> put_if(:uid, e.uid)
          |> put_if(:summary, e.summary)
          |> put_if(:description, e.description)
          |> put_if(:location, e.location)
          |> put_if(:dtstart, e.dtstart)
          |> put_if(:dtend, e.dtend)
          |> put_if(:organizer, e.organizer)
          |> put_if(:created, e.inserted_at)
          |> put_if(:modified, e.updated_at)
          |> put_if(
            :"x-rsvp-url",
            if(e.rsvpable, do: url(~p"/members/registration?rsvp=#{e.uid}"), else: nil)
          )
        end

      ics_content = generate_rfc5545_compliant_ics(%ICalendar{events: ics_events})

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(inline; filename="calendar.ics"))
      |> send_resp(200, ics_content)
    end
  end

  defp put_if(event, _key, nil), do: event
  defp put_if(event, key, value), do: Map.put(event, key, value)

  defp generate_rfc5545_compliant_ics(calendar) do
    calendar
    |> ICalendar.to_ics()
    |> fix_line_endings()
    |> fold_long_lines()
  end

  defp fix_line_endings(ics_content) do
    ics_content
    |> String.replace("\r\n", "\n")
    |> String.replace("\n", "\r\n")
  end

  defp fold_long_lines(ics_content) do
    ics_content
    |> String.split("\r\n")
    |> Enum.map(&fold_line/1)
    |> Enum.join("\r\n")
  end

  defp fold_line(line) when byte_size(line) <= 75, do: line

  defp fold_line(line) do
    fold_line_recursive(line, 75, [])
  end

  defp fold_line_recursive(line, max_length, acc) when byte_size(line) <= max_length do
    [line | acc] |> Enum.reverse() |> Enum.join("\r\n")
  end

  defp fold_line_recursive(line, max_length, acc) do
    <<chunk::binary-size(^max_length), rest::binary>> = line
    fold_line_recursive(" " <> rest, 74, [chunk | acc])
  end
end
