defmodule IeeeTamuPortalWeb.AdminCheckinsExportController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortal.Members.EventCheckin
  alias NimbleCSV.RFC4180, as: CSV

  def download(conn, params) do
    year = Settings.get_registration_year!()
    event_uid = params["event_uid"] |> blank_to_nil() |> cast_uuid()

    {rows, title} =
      if event_uid do
        {EventCheckin.emails_and_event_names_for_year(year, event_uid), event_title(event_uid)}
      else
        {EventCheckin.emails_and_event_names_for_year(year), nil}
      end

    csv =
      rows
      |> Enum.map(fn {created, email, uin, event_name} -> [created, email, uin, event_name] end)
      |> then(fn rs -> CSV.dump_to_iodata([["date", "email", "uin", "event_name"] | rs]) end)

    suffix =
      if title,
        do: "_" <> String.replace(title, ~r/\W+/, "-"),
        else: ""

    filename = "checkins#{suffix}_#{year}_#{Date.utc_today() |> Date.to_iso8601()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  defp event_title(event_uid) do
    case Events.get_event(event_uid) do
      nil -> nil
      event -> event.summary
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value) when is_binary(value), do: value

  defp cast_uuid(nil), do: nil

  defp cast_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uid} -> uid
      :error -> nil
    end
  end
end
