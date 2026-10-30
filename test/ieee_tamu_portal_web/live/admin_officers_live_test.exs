defmodule IeeeTamuPortalWeb.AdminOfficersLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth,
    only: [admin_auth_conn: 1, officer_auth_conn: 1]

  alias IeeeTamuPortal.{Accounts, Members}

  describe "access control" do
    test "redirects unauthenticated visitors to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/officers")
      assert redirected_to(conn) == ~p"/members/login"
    end

    test "redirects regular members home", %{conn: conn} do
      conn =
        conn
        |> log_in_member(confirmed_member_fixture())
        |> get(~p"/admin/officers")

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects officers who are not admins", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin"}}} =
               conn
               |> officer_auth_conn()
               |> live(~p"/admin/officers")
    end
  end

  describe "officer management" do
    test "renders the page and current privileged members", %{conn: conn} do
      officer = officer_member_fixture()
      admin = admin_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      assert html =~ "Officer Management"
      assert html =~ officer.email
      assert html =~ admin.email
    end

    test "grants the officer role by email", %{conn: conn} do
      member = confirmed_member_fixture()

      {:ok, view, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      html =
        view
        |> form("#grant-officer-form", %{"email" => member.email, "role" => "officer"})
        |> render_submit()

      assert html =~ "#{member.email} is now Officer."
      assert Accounts.get_member!(member.id).role == :officer
    end

    test "promotes an officer to admin and back", %{conn: conn} do
      member = officer_member_fixture()

      {:ok, view, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      view
      |> element(
        "button[phx-click=update_role][phx-value-id='#{member.id}'][phx-value-role='admin']"
      )
      |> render_click()

      assert Accounts.get_member!(member.id).role == :admin

      view
      |> element(
        "button[phx-click=update_role][phx-value-id='#{member.id}'][phx-value-role='officer']"
      )
      |> render_click()

      assert Accounts.get_member!(member.id).role == :officer
    end

    test "revokes access", %{conn: conn} do
      member = officer_member_fixture()

      {:ok, view, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      view
      |> element("button[phx-click=revoke][phx-value-id='#{member.id}']")
      |> render_click()

      assert Accounts.get_member!(member.id).role == :member
    end

    test "does not allow an admin to remove their own admin access", %{conn: conn} do
      admin = admin_member_fixture()

      {:ok, view, _html} =
        conn
        |> log_in_member(admin)
        |> live(~p"/admin/officers")

      html =
        render_click(view, "update_role", %{"id" => admin.id, "role" => "officer"})

      assert html =~ "You cannot remove your own admin access."
      assert Accounts.get_member!(admin.id).role == :admin
    end

    test "shows an error for an unknown email", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      html =
        view
        |> form("#grant-officer-form", %{"email" => "nobody@tamu.edu", "role" => "officer"})
        |> render_submit()

      assert html =~ "No member account found"
    end

    test "requires the account to be confirmed before granting access", %{conn: conn} do
      member = member_fixture()

      {:ok, view, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      html =
        view
        |> form("#grant-officer-form", %{"email" => member.email, "role" => "officer"})
        |> render_submit()

      assert html =~ "must confirm their email address"
      assert Accounts.get_member!(member.id).role == :member
    end
  end

  describe "officers missing an IEEE membership number" do
    test "lists officers and admins without a number, including members with no info row", %{
      conn: conn
    } do
      officer_without_info = officer_member_fixture()

      admin_with_nil_number = admin_member_fixture()
      create_member_info(admin_with_nil_number, %{ieee_membership_number: nil})

      officer_with_number = officer_member_fixture()
      create_member_info(officer_with_number, %{ieee_membership_number: 97_775_577})

      regular_without_number = confirmed_member_fixture()
      create_member_info(regular_without_number, %{ieee_membership_number: nil})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/officers")

      missing_html = render(element(lv, "#missing-ieee-members"))

      assert missing_html =~ "Officers missing an IEEE membership number"
      assert missing_html =~ officer_without_info.email
      assert missing_html =~ admin_with_nil_number.email
      refute missing_html =~ officer_with_number.email
      refute missing_html =~ regular_without_number.email
    end

    test "shows an all-clear message when every privileged account has a number", %{
      conn: conn
    } do
      admin = admin_member_fixture()
      create_member_info(admin, %{ieee_membership_number: 97_775_578})

      {:ok, lv, _html} =
        conn
        |> log_in_member(admin)
        |> live(~p"/admin/officers")

      missing_html = render(element(lv, "#missing-ieee-members"))

      assert missing_html =~ "All officers and admins have an IEEE membership number."
    end
  end

  defp create_member_info(member, overrides) do
    defaults = %{
      uin: unique_uin(),
      first_name: "Test",
      last_name: "User",
      tshirt_size: :M,
      graduation_year: 2026,
      major: :ELEN,
      gender: :Male,
      international_student: false,
      phone_number: "123-456-7890"
    }

    attrs = Map.merge(defaults, overrides)

    {:ok, _info} = Members.create_member_info(member, attrs)
  end

  defp unique_uin do
    n = System.unique_integer([:positive])
    "#{rem(n, 900) + 100}00#{rem(n * 7, 9000) + 1000}" |> String.to_integer()
  end
end
