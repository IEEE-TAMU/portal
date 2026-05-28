defmodule IeeeTamuPortalWeb.Api.V1.MemberControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.ApiFixtures

  alias IeeeTamuPortal.Members

  describe "GET /api/v1/members" do
    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/members")

      assert %{
               "error" => "Unauthorized: Invalid or missing API token"
             } == json_response(conn, 401)
    end

    test "returns members list with admin API key", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
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

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members")

      assert conn.status == 200
      members_list = json_response(conn, 200)
      assert is_list(members_list)
      assert length(members_list) > 0
    end

    test "admin can see all members", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      member1 = confirmed_member_fixture()

      {:ok, _info} =
        Members.create_member_info(member1, %{
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

      member2 = confirmed_member_fixture()

      {:ok, _info} =
        Members.create_member_info(member2, %{
          uin: unique_uin(),
          first_name: "Bob",
          last_name: "Jones",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members")

      members_list = json_response(conn, 200)
      assert length(members_list) >= 2
    end
  end

  describe "GET /api/v1/members/:id" do
    test "admin can view any member by ID", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      member = confirmed_member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: unique_uin(),
          first_name: "Charlie",
          last_name: "Brown",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members/#{member.id}")

      assert conn.status == 200
      member_data = json_response(conn, 200)
      assert member_data["email"] == member.email
      assert member_data["info"]["first_name"] == "Charlie"
    end

    test "returns 404 for non-existent member", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members/999999")

      assert conn.status == 404
    end

    test "member can view their own profile", %{conn: conn} do
      member = confirmed_member_fixture()
      {token, _api_key} = member_api_key_fixture(member)

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members/#{member.id}")

      assert conn.status == 200
      member_data = json_response(conn, 200)
      assert member_data["email"] == member.email
    end

    test "member cannot view another member's profile", %{conn: conn} do
      member1 = confirmed_member_fixture()
      {token, _api_key} = member_api_key_fixture(member1)

      member2 = confirmed_member_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/members/#{member2.id}")

      assert conn.status == 403
    end
  end

  defp unique_uin do
    first = System.unique_integer([:positive]) |> rem(900) |> Kernel.+(100)
    last = System.unique_integer([:positive]) |> rem(10_000)
    "#{first}00#{String.pad_leading(Integer.to_string(last), 4, "0")}" |> String.to_integer()
  end
end
