defmodule IeeeTamuPortalWeb.Api.V1.AdminCalendarController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortalWeb.Api.CalendarRendering

  tags ["calendar"]

  admin_operation :index,
    summary: "Admin iCalendar feed (includes private events)",
    description:
      "Returns an iCalendar (ICS) feed of all events, including private ones. Requires admin API key.",
    responses: [
      ok: {"ICS feed (all events)", "text/calendar", %OpenApiSpex.Schema{type: :string}}
    ] do
    fn conn, _params, _api_key ->
      CalendarRendering.render_ics(conn, Events.list_events(include_private: true))
    end
  end
end
