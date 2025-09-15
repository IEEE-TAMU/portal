defmodule IeeeTamuPortalWeb.Api.V1.DiscordRolesControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.ApiFixtures

  describe "GET /api/v1/discord/roles" do
    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/discord/roles?email=nobody@example.com")

      assert %{"error" => "Unauthorized: Invalid or missing API token"} ==
               json_response(conn, 401)
    end

    test "returns 403 for non-admin API key", %{conn: conn} do
      {token, _api_key} = member_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/discord/roles?email=nobody@example.com")

      assert %{"error" => "Forbidden: Admin access required"} == json_response(conn, 403)
    end

    test "returns 404 when member not found (admin)", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/discord/roles?email=nobody@example.com")

      assert %{"error" => "Member not found"} = json_response(conn, 404)
    end

    test "returns 404 when member exists but Discord not linked (admin)", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> get(~p"/api/v1/discord/roles?email=#{member.email}")

      assert %{"error" => "Discord not linked for member"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/discord/roles" do
    test "returns 403 with regular API key (non-admin)", %{conn: conn} do
      {token, _api_key} = member_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/discord/roles", %{email: "user@example.com", role: "Member"})

      assert %{"error" => "Forbidden: Admin access required"} == json_response(conn, 403)
    end

    test "returns 404 when member exists but Discord not linked (admin)", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/discord/roles", %{email: member.email, role: "Member"})

      assert %{"error" => "Discord not linked for member"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/discord/roles" do
    test "returns 403 with regular API key (non-admin)", %{conn: conn} do
      {token, _api_key} = member_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> delete(~p"/api/v1/discord/roles?email=user@example.com&role=Member")

      assert %{"error" => "Forbidden: Admin access required"} == json_response(conn, 403)
    end

    test "returns 404 when member exists but Discord not linked (admin)", %{conn: conn} do
      member = member_fixture()
      {token, _api_key} = admin_api_key_fixture()

      conn =
        conn
        |> put_token_header(token)
        |> delete(~p"/api/v1/discord/roles?email=#{member.email}&role=Member")

      assert %{"error" => "Discord not linked for member"} = json_response(conn, 404)
    end
  end
end
