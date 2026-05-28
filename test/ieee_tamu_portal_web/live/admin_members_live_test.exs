defmodule IeeeTamuPortalWeb.AdminMembersLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Members

  setup do
    registration_year_setting_fixture("2025")
    :ok
  end

  describe "admin auth requirement" do
    test "requires admin basic auth", %{conn: conn} do
      conn = get(conn, ~p"/admin/members")
      assert conn.status == 401
    end
  end

  describe "Admin Members page" do
    test "renders the members page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Members"
      assert html =~ "A list of all members in the IEEE TAMU Portal"
    end

    test "lists members in the table", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "Alice", last_name: "Smith"})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ member.email
    end

    test "shows member name when info exists", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "Alice", last_name: "Smith"})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Alice Smith"
    end

    test "shows preferred name when set", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "Alice", last_name: "Smith", preferred_name: "Al"})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Al Smith"
    end

    test "shows email when no info exists", %{conn: conn} do
      member = confirmed_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ member.email
    end

    test "shows confirmed status for confirmed members", %{conn: conn} do
      confirmed_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Confirmed"
    end

    test "shows unconfirmed status for unconfirmed members", %{conn: conn} do
      member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Unconfirmed"
    end

    test "shows payment status as Pending by default", %{conn: conn} do
      confirmed_member_fixture()
      registration_year_setting_fixture("2025")

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Pending"
    end

    test "shows payment status as Override when override is set", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)
      {:ok, registration} = Members.get_or_create_registration(member, 2025)
      Members.update_registration(registration, %{payment_override: true})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Override"
    end

    test "shows Not Uploaded for members without resume", %{conn: conn} do
      confirmed_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      # S3 is configured, but member has no resume
      assert html =~ "Not Uploaded"
    end

    test "shows filter form", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Filter by Email"
      assert html =~ "Filter by Name"
      assert html =~ "Filter"
      assert html =~ "Clear"
    end

    test "shows empty state when no members exist", %{conn: conn} do
      # No members created
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "No members match your search criteria"
    end

    test "shows IEEE validate button when member has ieee_membership_number", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{ieee_membership_number: "97775577"})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Validate"
    end

    test "does not show IEEE validate button when no ieee_membership_number", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{ieee_membership_number: nil})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      refute html =~ "Validate"
    end

    test "shows Resend button for unconfirmed members", %{conn: conn} do
      member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      assert html =~ "Resend"
    end

    test "does not show Resend button for confirmed members", %{conn: conn} do
      confirmed_member_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      refute html =~ "Resend"
    end
  end

  describe "filtering" do
    test "has filter input fields", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      html = render(lv)
      assert html =~ "Filter by Email"
      assert html =~ "Filter by Name"
    end
  end

  describe "view member modal" do
    test "opens view modal for a member with info", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "ViewTest", last_name: "User"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "View")
      |> render_click()

      html = render(lv)
      assert html =~ "View Member"
      assert html =~ "ViewTest"
      assert html =~ member.email
    end

    test "view modal shows not provided for empty fields", %{conn: conn} do
      _member = confirmed_member_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "View")
      |> render_click()

      html = render(lv)
      assert html =~ "Not provided"
    end

    test "view modal has Edit Member button", %{conn: conn} do
      _member = confirmed_member_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "View")
      |> render_click()

      html = render(lv)
      assert html =~ "Edit Member"
    end

    test "closes view modal", %{conn: conn} do
      _member = confirmed_member_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "View")
      |> render_click()

      lv
      |> element("button", "Close")
      |> render_click()

      html = render(lv)
      refute html =~ "View Member"
    end
  end

  describe "edit member modal" do
    test "opens edit modal for a member with info", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "EditTest", last_name: "User"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Edit")
      |> render_click()

      html = render(lv)
      assert html =~ "Edit Member"
      assert html =~ member.email
      assert html =~ "EditTest"
    end

    test "validates edit form on change", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "EditTest", last_name: "User"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Edit")
      |> render_click()

      lv
      |> form("#member_info_form", %{"info" => %{"first_name" => ""}})
      |> render_change()

      html = render(lv)
      assert html =~ "can&#39;t be blank"
    end

    test "closes edit modal", %{conn: conn} do
      _member = confirmed_member_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Edit")
      |> render_click()

      lv
      |> element("button", "Cancel")
      |> render_click()

      html = render(lv)
      refute html =~ "Edit Member"
    end
  end

  describe "payment override" do
    test "toggles payment override from pending to override", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Pending")
      |> render_click()

      html = render(lv)
      assert html =~ "Payment override enabled"

      # Should now show Override
      assert html =~ "Override"
    end

    test "toggles payment override from override back to pending", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member)
      {:ok, registration} = Members.get_or_create_registration(member, 2025)
      Members.update_registration(registration, %{payment_override: true})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Override")
      |> render_click()

      html = render(lv)
      assert html =~ "Payment override disabled"
    end
  end

  describe "resend confirmation" do
    test "resends confirmation email for unconfirmed member", %{conn: conn} do
      member_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/members")

      lv
      |> element("button", "Resend")
      |> render_click()

      html = render(lv)
      assert html =~ "Confirmation email sent"
    end
  end

  defp create_member_info(member, overrides \\ %{}) do
    defaults = %{
      uin: 123_001_234,
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
end
