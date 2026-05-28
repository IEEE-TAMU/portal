defmodule IeeeTamuPortalWeb.OAuthControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortal.AccountsFixtures

  describe "GET /auth/:provider" do
    test "returns 404 for invalid provider", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/auth/invalid_provider")
      end
    end

    test "discord authorize redirects to discord", %{conn: conn} do
      conn = get(conn, ~p"/auth/discord")
      assert redirected_to(conn) =~ "discord"
    end

    test "google authorize redirects to google", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")
      assert redirected_to(conn) =~ "google"
    end
  end

  describe "GET /auth/:provider/callback" do
    test "discord callback with error redirects to login", %{conn: conn} do
      conn = get(conn, ~p"/auth/discord/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Discord login was cancelled or failed."
    end

    test "discord callback with error when logged in redirects to settings", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      conn = get(conn, ~p"/auth/discord/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Discord authentication was cancelled or failed."
    end

    test "google callback with error redirects to login", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Google login was cancelled or failed."
    end

    test "google callback with error when logged in redirects to settings", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      conn = get(conn, ~p"/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Google authentication was cancelled or failed."
    end
  end
end
