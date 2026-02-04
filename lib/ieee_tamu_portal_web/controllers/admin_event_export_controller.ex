defmodule IeeeTamuPortalWeb.AdminEventExportController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Events
  alias NimbleCSV.RFC4180, as: CSV

  def download_rsvps(conn, %{"event_uid" => event_uid}) do
    event = Events.get_event!(event_uid)
    rows = Events.emails_and_names_for_event_rsvps(event_uid)

    csv =
      rows
      |> Enum.map(fn {created, email, name, uin, _event_title} -> [created, email, name, uin] end)
      |> then(fn rs -> CSV.dump_to_iodata([["date", "email", "name", "uin"] | rs]) end)

    # Create filename-safe event name
    safe_event_name =
      event.summary
      |> String.replace(~r/\W+/, "-")
      |> String.downcase()

    filename = "rsvps_#{safe_event_name}_#{Date.utc_today() |> Date.to_iso8601()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  def download_checkins(conn, %{"event_uid" => event_uid}) do
    event = Events.get_event!(event_uid)
    rows = Events.emails_and_names_for_event_checkins(event.summary)

    csv =
      rows
      |> Enum.map(fn {created, email, name, uin, _event_name} -> [created, email, name, uin] end)
      |> then(fn rs -> CSV.dump_to_iodata([["date", "email", "name", "uin"] | rs]) end)

    # Create filename-safe event name
    safe_event_name =
      event.summary
      |> String.replace(~r/\W+/, "-")
      |> String.downcase()

    filename = "checkins_#{safe_event_name}_#{Date.utc_today() |> Date.to_iso8601()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end
end
