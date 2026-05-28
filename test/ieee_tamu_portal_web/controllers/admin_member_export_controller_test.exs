defmodule IeeeTamuPortalWeb.AdminMemberExportControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Members

  setup do
    registration_year_setting_fixture("2025")
    :ok
  end

  test "requires admin auth", %{conn: conn} do
    conn = get(conn, ~p"/admin/download-members")
    assert conn.status == 401
  end

  test "returns CSV with headers", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-members")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert get_resp_header(conn, "content-disposition") |> List.first() =~ "attachment"

    body = response(conn, 200)
    assert body =~ "id,email,confirmed_at"
    assert body =~ "uin,first_name,last_name"
  end

  test "includes member data in CSV", %{conn: conn} do
    uin = unique_uin()
    member = confirmed_member_fixture()

    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: uin,
        first_name: "Alice",
        last_name: "Smith",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-members")

    body = response(conn, 200)
    assert body =~ "Alice"
    assert body =~ "Smith"
    assert body =~ member.email
  end

  test "filters by paid=true", %{conn: conn} do
    member = confirmed_member_fixture()

    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: unique_uin(),
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    {:ok, registration} = Members.get_or_create_registration(member, 2025)
    Members.update_registration(registration, %{payment_override: true})

    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-members?paid=true")

    assert conn.status == 200
    body = response(conn, 200)
    assert body =~ member.email
  end

  test "filename includes members prefix", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-members")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "members_2025_"
  end

  test "filename includes paid_members prefix with paid filter", %{conn: conn} do
    conn =
      conn
      |> admin_auth_conn()
      |> get(~p"/admin/download-members?paid=true")

    disposition = get_resp_header(conn, "content-disposition") |> List.first()
    assert disposition =~ "paid_members_"
  end

  defp unique_uin do
    System.unique_integer([:positive]) |> rem(900_000_000) |> Kernel.+(100_000_000)
  end
end
