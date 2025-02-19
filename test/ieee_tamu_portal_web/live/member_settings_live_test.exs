defmodule IeeeTamuPortalWeb.MemberSettingsLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortal.Accounts
  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_member(member_fixture())
        |> live(~p"/members/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if member is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/members/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_member_password()
      member = member_fixture(%{password: password})
      %{conn: log_in_member(conn, member), member: member, password: password}
    end

    test "updates the member email", %{conn: conn, password: password, member: member} do
      new_email = unique_member_email()

      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "member" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_member_by_email(member.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "member" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, member: member} do
      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "member" => %{"email" => member.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_member_password()
      member = member_fixture(%{password: password})
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
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "member" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      member = member_fixture()
      email = unique_member_email()

      token =
        extract_member_token(fn url ->
          Accounts.deliver_member_update_email_instructions(
            %{member | email: email},
            member.email,
            url
          )
        end)

      %{conn: log_in_member(conn, member), token: token, email: email, member: member}
    end

    test "updates the member email once", %{
      conn: conn,
      member: member,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/members/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_member_by_email(member.email)
      assert Accounts.get_member_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/members/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, member: member} do
      {:error, redirect} = live(conn, ~p"/members/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_member_by_email(member.email)
    end

    test "redirects if member is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/members/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
