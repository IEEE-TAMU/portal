defmodule IeeeTamuPortalWeb.Api.V1.CalendarController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Events

  tags ["calendar"]

  insecure_operation :index,
    summary: "Public iCalendar feed",
    description: "Returns an iCalendar (ICS) feed of events. No authentication required.",
    responses: [
      ok: {"ICS feed", "text/calendar", %OpenApiSpex.Schema{type: :string}}
    ] do
    fn conn, _params ->
      events = Events.list_events()

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
          |> put_if(:"x-rsvp-url", url(~p"/members/registration?rsvp=#{e.uid}"))
        end

      # Generate ICS with custom serialization for RFC 5545 compliance
      ics_content = generate_rfc5545_compliant_ics(%ICalendar{events: ics_events})

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(inline; filename="calendar.ics"))
      |> send_resp(200, ics_content)
    end
  end

  defp put_if(event, _key, nil), do: event
  defp put_if(event, key, value), do: Map.put(event, key, value)

  # TODO: updtream this - Write a library?
  # Generate RFC 5545 compliant ICS content
  defp generate_rfc5545_compliant_ics(calendar) do
    # Use the standard ICalendar library to generate the base content
    ics_content = ICalendar.to_ics(calendar)

    # Apply RFC 5545 compliance fixes
    ics_content
    |> fix_line_endings()
    |> fold_long_lines()
  end

  # Convert LF to CRLF as required by RFC 5545
  defp fix_line_endings(ics_content) do
    ics_content
    # Normalize first (in case already has CRLF)
    |> String.replace("\r\n", "\n")
    # Convert to CRLF
    |> String.replace("\n", "\r\n")
  end

  # Fold lines longer than 75 characters according to RFC 5545
  defp fold_long_lines(ics_content) do
    ics_content
    |> String.split("\r\n")
    |> Enum.map(&fold_line/1)
    |> Enum.join("\r\n")
  end

  # Fold a single line if it exceeds 75 characters
  defp fold_line(line) when byte_size(line) <= 75, do: line

  defp fold_line(line) do
    # RFC 5545 3.1: Lines should be folded at 75 characters
    # Continuation lines start with a space or tab
    fold_line_recursive(line, 75, [])
  end

  defp fold_line_recursive(line, max_length, acc) when byte_size(line) <= max_length do
    # Last chunk - no more folding needed
    result = [line | acc] |> Enum.reverse() |> Enum.join("\r\n")
    result
  end

  defp fold_line_recursive(line, max_length, acc) do
    # Take the first max_length characters
    <<chunk::binary-size(max_length), rest::binary>> = line

    # Add this chunk to accumulator and continue with rest
    # Rest gets prefixed with space for continuation
    new_acc = [chunk | acc]
    # 74 because we prefix with space
    fold_line_recursive(" " <> rest, 74, new_acc)
  end
end
