defmodule IeeeTamuPortalWeb.AdminEventExportControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.{Events, Members}

  @event_attrs %{
    dtstart: DateTime.utc_now() |> DateTime.truncate(:second),
    dtend: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
    summary: "Test Event",
    description: "Event description",
    location: "ZACH 100",
    organizer: "IEEE TAMU"
  }

  setup do
    {:ok, event} = Events.create_event(@event_attrs)
    %{event: event}
  end

  test "requires admin auth for rsvps download", %{conn: conn, event: event} do
    conn = get(conn, ~p"/admin/download-event-rsvps/#{event.uid}")
    assert conn.status == 401
  end

  test "requires admin auth for checkins download", %{conn: conn, event: event} do
    conn = get(conn, ~p"/admin/download-event-checkins/#{event.uid}")
    assert conn.status == 401
  end

  test "returns RSVP CSV with headers", %{conn: conn, event: event} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-event-rsvps/#{event.uid}")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert get_resp_header(conn, "content-disposition") |> List.first() =~ "attachment"

    body = response(conn, 200)
    assert body =~ "date,email,name,uin"
  end

  test "includes RSVP data in CSV when member has info", %{conn: conn, event: event} do
    member = confirmed_member_fixture()

    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: unique_uin(),
        first_name: "Alice",
        last_name: "Smith",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    {:ok, _rsvp} = Events.create_rsvp(member.id, event.uid)

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-event-rsvps/#{event.uid}")

    body = response(conn, 200)
    assert body =~ member.email
  end

  test "returns checkins CSV with headers", %{conn: conn, event: event} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-event-checkins/#{event.uid}")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    body = response(conn, 200)
    assert body =~ "date,email,name,uin"
  end

  test "filename for rsvps includes event name", %{conn: conn, event: event} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-event-rsvps/#{event.uid}")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "rsvps_test-event_"
  end

  test "filename for checkins includes event name", %{conn: conn, event: event} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-event-checkins/#{event.uid}")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "checkins_test-event_"
  end

  defp unique_uin do
    first = System.unique_integer([:positive]) |> rem(900) |> Kernel.+(100)
    last = System.unique_integer([:positive]) |> rem(10_000)
    "#{first}00#{String.pad_leading(Integer.to_string(last), 4, "0")}" |> String.to_integer()
  end
end
