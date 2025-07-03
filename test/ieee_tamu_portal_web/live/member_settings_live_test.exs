defmodule IeeeTamuPortalWeb.MemberSettingsLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortal.Accounts
  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_member(confirmed_member_fixture())
        |> live(~p"/members/settings")

      assert html =~ "Change Password"
    end

    test "redirects if member is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/members/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_member_password()
      member = confirmed_member_fixture(%{password: password})
      %{conn: log_in_member(conn, member), member: member, password: password}
    end

    test "updates the member password", %{conn: conn, member: member, password: password} do
      new_password = valid_member_password()

      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "member" => %{
            "email" => member.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/members/settings"

      assert get_session(new_password_conn, :member_token) != get_session(conn, :member_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_member_by_email_and_password(member.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "member" => %{
            "password" => "short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 8 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "member" => %{
            "password" => "short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 8 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end
end
