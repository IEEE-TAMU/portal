defmodule IeeeTamuPortalWeb.AdminCheckinsExportControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Members.EventCheckin

  setup do
    registration_year_setting_fixture("2025")
    current_event_setting_fixture("test_event")
    :ok
  end

  test "requires admin auth", %{conn: conn} do
    conn = get(conn, ~p"/admin/download-checkins")
    assert conn.status == 401
  end

  test "returns CSV with headers", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-checkins")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert get_resp_header(conn, "content-disposition") |> List.first() =~ "attachment"

    body = response(conn, 200)
    assert body =~ "date,email,uin,event_name"
  end

  test "includes checkin data in CSV", %{conn: conn} do
    uin = unique_uin()
    member = confirmed_member_fixture()

    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: uin,
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    EventCheckin.insert_for_member_id(member.id)

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-checkins")

    body = response(conn, 200)
    assert body =~ member.email
    assert body =~ "test_event"
  end

  test "filters by event_name", %{conn: conn} do
    uin = unique_uin()
    member = confirmed_member_fixture()

    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: uin,
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    EventCheckin.insert_for_member_id(member.id)

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-checkins?event_name=test_event")

    body = response(conn, 200)
    assert body =~ "test_event"
  end

  test "filename includes checkins prefix and year", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-checkins")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "checkins_2025_"
  end

  test "filename includes event name when filtered", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-checkins?event_name=my_event")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "my_event"
  end

  defp unique_uin do
    first = System.unique_integer([:positive]) |> rem(900) |> Kernel.+(100)
    last = System.unique_integer([:positive]) |> rem(10_000)
    "#{first}00#{String.pad_leading(Integer.to_string(last), 4, "0")}" |> String.to_integer()
  end
end
