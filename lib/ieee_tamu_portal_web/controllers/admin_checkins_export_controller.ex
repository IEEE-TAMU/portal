defmodule IeeeTamuPortalWeb.AdminCheckinsExportController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortal.Members.EventCheckin
  alias NimbleCSV.RFC4180, as: CSV

  def download(conn, params) do
    year = Settings.get_registration_year!()
    event_name = Map.get(params, "event_name")

    rows =
      case event_name do
        nil -> EventCheckin.emails_and_event_names_for_year(year)
        "" -> EventCheckin.emails_and_event_names_for_year(year)
        name when is_binary(name) -> EventCheckin.emails_and_event_names_for_year(year, name)
      end

    csv =
      rows
      |> Enum.map(fn {created, email, uin, event_name} -> [created, email, uin, event_name] end)
      |> then(fn rs -> CSV.dump_to_iodata([["date", "email", "uin", "event_name"] | rs]) end)

    suffix =
      if is_binary(event_name) and event_name != "",
        do: "_" <> String.replace(event_name, ~r/\W+/, "-"),
        else: ""

    filename = "checkins#{suffix}_#{year}_#{Date.utc_today() |> Date.to_iso8601()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end
end
