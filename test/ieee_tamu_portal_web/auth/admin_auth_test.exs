defmodule IeeeTamuPortalWeb.Auth.AdminAuthTest do
  use IeeeTamuPortalWeb.ConnCase

  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortalWeb.Auth.AdminAuth

  describe "admin_auth/2" do
    test "redirects unauthenticated visitors to login", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_member, nil)
        |> AdminAuth.admin_auth([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/members/login"
    end

    test "denies a regular member and redirects home", %{conn: conn} do
      member = confirmed_member_fixture()

      conn =
        conn
        |> log_in_member(member)
        |> fetch_flash()
        |> assign(:current_member, member)
        |> AdminAuth.admin_auth([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "do not have permission"
    end

    test "allows an officer", %{conn: conn} do
      member = officer_member_fixture()

      conn =
        conn
        |> log_in_member(member)
        |> assign(:current_member, member)
        |> AdminAuth.admin_auth([])

      refute conn.halted
    end

    test "allows an admin", %{conn: conn} do
      member = admin_member_fixture()

      conn =
        conn
        |> log_in_member(member)
        |> assign(:current_member, member)
        |> AdminAuth.admin_auth([])

      refute conn.halted
    end
  end
end
