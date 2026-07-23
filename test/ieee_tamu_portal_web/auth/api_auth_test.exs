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

    test "returns ok with valid token in query param", %{conn: conn} do
      {token, api_key} = admin_api_key_fixture()
      conn = put_req_header(conn, "accept", "text/calendar")

      assert {:ok, returned_key, conn} = ApiAuth.get_api_key(%{conn | query_string: "token=#{token}"})
      assert returned_key.id == api_key.id
      assert not conn.halted
    end

    test "returns error for invalid token in query param", %{conn: conn} do
      conn = %{conn | query_string: "token=bogus"}

      assert {:error, :invalid_token, conn} = ApiAuth.get_api_key(conn)
      assert conn.status == 401
      assert conn.halted
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

  describe "try_get_admin_key/1" do
    test "returns error when no auth at all", %{conn: conn} do
      assert {:error, conn} = ApiAuth.try_get_admin_key(conn)
      assert not conn.halted
    end

    test "returns ok with admin Bearer token", %{conn: conn} do
      {token, api_key} = admin_api_key_fixture()
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:ok, returned_key, conn} = ApiAuth.try_get_admin_key(conn)
      assert returned_key.id == api_key.id
      assert not conn.halted
    end

    test "returns error with member Bearer token (not admin)", %{conn: conn} do
      member = IeeeTamuPortal.AccountsFixtures.member_fixture()
      {token, _api_key} = member_api_key_fixture(member)
      conn = put_req_header(conn, "authorization", "Bearer #{token}")

      assert {:error, conn} = ApiAuth.try_get_admin_key(conn)
      assert not conn.halted
    end

    test "returns error with invalid Bearer token", %{conn: conn} do
      conn = put_req_header(conn, "authorization", "Bearer bogus")

      assert {:error, conn} = ApiAuth.try_get_admin_key(conn)
      assert not conn.halted
    end

    test "returns ok with admin token in query param", %{conn: conn} do
      {token, api_key} = admin_api_key_fixture()

      assert {:ok, returned_key, conn} = ApiAuth.try_get_admin_key(%{conn | query_string: "token=#{token}"})
      assert returned_key.id == api_key.id
      assert not conn.halted
    end

    test "returns error with invalid token in query param", %{conn: conn} do
      assert {:error, conn} = ApiAuth.try_get_admin_key(%{conn | query_string: "token=bogus"})
      assert not conn.halted
    end

    test "returns error with non-admin token in query param", %{conn: conn} do
      member = IeeeTamuPortal.AccountsFixtures.member_fixture()
      {token, _api_key} = member_api_key_fixture(member)

      assert {:error, conn} = ApiAuth.try_get_admin_key(%{conn | query_string: "token=#{token}"})
      assert not conn.halted
    end

    test "strips token from query string after extraction", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      conn = %{conn | query_string: "token=#{token}&foo=bar"}

      assert {:ok, _key, conn} = ApiAuth.try_get_admin_key(conn)
      assert conn.query_string == "foo=bar"
    end

    test "strips token from query string leaving empty string when no other params", %{conn: conn} do
      {token, _api_key} = admin_api_key_fixture()
      conn = %{conn | query_string: "token=#{token}"}

      assert {:ok, _key, conn} = ApiAuth.try_get_admin_key(conn)
      assert conn.query_string == ""
    end
  end
end
