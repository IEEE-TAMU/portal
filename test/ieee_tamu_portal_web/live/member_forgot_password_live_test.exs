defmodule IeeeTamuPortalWeb.MemberForgotPasswordLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/members/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/members/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/members/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_member(member_fixture())
        |> live(~p"/members/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{member: member_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, member: member} do
      {:ok, lv, _html} = live(conn, ~p"/members/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", member: %{"email" => member.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.MemberToken, member_id: member.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", member: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.MemberToken) == []
    end
  end
end
