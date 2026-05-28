defmodule IeeeTamuPortalWeb.Auth.ApiAuthTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.ApiFixtures

  alias IeeeTamuPortalWeb.Auth.ApiAuth

  describe "get_api_key/1" do
    test "returns error when no authorization header", %{conn: conn} do
      assert {:error, :missing_token, conn} = ApiAuth.get_api_key(conn)
      assert conn.status == 401
      assert conn.halted
    end

    test "returns error for invalid token format", %{conn: conn} do
      conn = put_req_header(conn, "authorization", "InvalidFormat token")

      assert {:error, :missing_token, conn} = ApiAuth.get_api_key(conn)
      assert conn.status == 401
      assert conn.halted
    end

    test "returns error for non-existent token", %{conn: conn} do
      conn = put_req_header(conn, "authorization", "Bearer nonexistent_token")

      assert {:error, :invalid_token, conn} = ApiAuth.get_api_key(conn)
      assert conn.status == 401
      assert conn.halted
    end

    test "returns ok with valid admin API key", %{conn: conn} do
      {token, api_key} = admin_api_key_fixture()
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:ok, returned_key, conn} = ApiAuth.get_api_key(conn)
      assert returned_key.id == api_key.id
      assert not conn.halted
    end

    test "returns ok with valid member API key", %{conn: conn} do
      member = IeeeTamuPortal.AccountsFixtures.member_fixture()
      {token, api_key} = member_api_key_fixture(member)
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:ok, returned_key, conn} = ApiAuth.get_api_key(conn)
      assert returned_key.id == api_key.id
      assert not conn.halted
    end
  end

  describe "require_admin/1" do
    test "returns ok for admin API key", %{conn: conn} do
      {token, api_key} = admin_api_key_fixture()
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:ok, returned_key, conn} = ApiAuth.require_admin(conn)
      assert returned_key.id == api_key.id
      assert not conn.halted
    end

    test "returns error for member API key", %{conn: conn} do
      member = IeeeTamuPortal.AccountsFixtures.member_fixture()
      {token, _api_key} = member_api_key_fixture(member)
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:error, :not_admin, conn} = ApiAuth.require_admin(conn)
      assert conn.status == 403
      assert conn.halted
    end

    test "returns error for missing token", %{conn: conn} do
      assert {:error, :missing_token, conn} = ApiAuth.require_admin(conn)
      assert conn.status == 401
      assert conn.halted
    end
  end

  describe "standard_auth_responses/0" do
    test "returns unauthorized response schema" do
      responses = ApiAuth.standard_auth_responses()
      assert Keyword.has_key?(responses, :unauthorized)
    end
  end

  describe "admin_auth_responses/0" do
    test "returns unauthorized and forbidden response schemas" do
      responses = ApiAuth.admin_auth_responses()
      assert Keyword.has_key?(responses, :unauthorized)
      assert Keyword.has_key?(responses, :forbidden)
    end
  end

  describe "auth_header/0" do
    test "returns authorization" do
      assert ApiAuth.auth_header() == "authorization"
    end
  end
end
