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
          |> put_if(:created, e.inserted_at)
          |> put_if(:last_modified, e.updated_at)
        end

      ics = %ICalendar{events: ics_events} |> ICalendar.to_ics()

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(inline; filename="calendar.ics"))
      |> send_resp(200, ics)
    end
  end

  defp put_if(event, _key, nil), do: event
  defp put_if(event, key, value), do: Map.put(event, key, value)
end
