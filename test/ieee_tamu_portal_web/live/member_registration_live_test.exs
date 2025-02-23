defmodule IeeeTamuPortalWeb.MemberRegistrationLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/members/register")

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_member(member_fixture())
        |> live(~p"/members/register")
        |> follow_redirect(conn, "/membership")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(member: %{"email" => "with spaces", "password" => "short"})

      assert result =~ "Register"
      assert result =~ "must be a TAMU email"
      assert result =~ "should be at least 8 character"
    end
  end

  describe "register member" do
    test "creates account and logs the member in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/register")

      email = unique_member_email()
      form = form(lv, "#registration_form", member: valid_member_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/membership"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/membership")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings"
      assert response =~ "Log out"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/register")

      member = member_fixture(%{email: "test@tamu.edu"})

      result =
        lv
        |> form("#registration_form",
          member: %{"email" => member.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/register")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Log in")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/members/login")

      assert login_html =~ "Log in"
    end
  end
end
