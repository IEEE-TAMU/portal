defmodule IeeeTamuPortalWeb.Auth.AdminAuthTest do
  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortalWeb.Auth.AdminAuth

  describe "admin_auth/2" do
    test "allows access with correct credentials", %{conn: conn} do
      username = Application.fetch_env!(:ieee_tamu_portal, AdminAuth)[:username]
      password = Application.fetch_env!(:ieee_tamu_portal, AdminAuth)[:password]

      credentials = Base.encode64("#{username}:#{password}")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> AdminAuth.admin_auth([])

      refute conn.halted
    end

    test "denies access with incorrect credentials", %{conn: conn} do
      credentials = Base.encode64("wrong:credentials")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> AdminAuth.admin_auth([])

      assert conn.halted
      assert conn.status == 401
    end

    test "denies access with no credentials", %{conn: conn} do
      conn = AdminAuth.admin_auth(conn, [])

      assert conn.halted
      assert conn.status == 401
    end

    test "denies access with malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Invalid header")
        |> AdminAuth.admin_auth([])

      assert conn.halted
      assert conn.status == 401
    end
  end
end
