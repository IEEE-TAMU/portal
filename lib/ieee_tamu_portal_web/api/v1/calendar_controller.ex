defmodule IeeeTamuPortalWeb.Api.V1.CalendarController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortalWeb.Api.CalendarRendering

  tags ["calendar"]

  insecure_operation :index,
    summary: "Public iCalendar feed",
    description: "Returns an iCalendar (ICS) feed of events. No authentication required.",
    responses: [
      ok: {"ICS feed", "text/calendar", %OpenApiSpex.Schema{type: :string}}
    ] do
    fn conn, _params ->
      CalendarRendering.render_ics(conn, Events.list_events())
    end
  end
end
