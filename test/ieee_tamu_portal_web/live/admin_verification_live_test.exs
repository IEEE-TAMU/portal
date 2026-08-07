defmodule IeeeTamuPortalWeb.AdminVerificationLiveTest do
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
      conn = get(conn, ~p"/admin/verification")
      assert conn.status == 401
    end
  end

  describe "Admin Verification page" do
    test "renders the verification page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      assert html =~ "IEEE Membership Verification"
    end

    test "shows empty state when no members need verification", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      assert html =~ "All caught up!"
      assert html =~ "No members are currently pending"
    end

    test "shows members with IEEE number and no override", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{ieee_membership_number: "97775577"})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      assert html =~ member.email
      assert html =~ "97775577"
      assert html =~ "Validate"
      assert html =~ "Approve"
    end

    test "does not show members without IEEE number", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{ieee_membership_number: nil})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      refute html =~ member.email
      assert html =~ "All caught up!"
    end

    test "does not show members who already have a payment override", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{ieee_membership_number: "97775577"})

      {:ok, registration} = Members.get_or_create_registration(member, 2025)
      Members.update_registration(registration, %{payment_override: true})

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      refute html =~ member.email
      assert html =~ "All caught up!"
    end

    test "shows multiple members pending verification", %{conn: conn} do
      member1 = confirmed_member_fixture()

      create_member_info(member1, %{
        first_name: "Alice",
        ieee_membership_number: "11111111",
        uin: 123_001_234
      })

      member2 = confirmed_member_fixture()

      create_member_info(member2, %{
        first_name: "Bob",
        ieee_membership_number: "22222222",
        uin: 123_001_235
      })

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      assert html =~ "Alice"
      assert html =~ "11111111"
      assert html =~ "Bob"
      assert html =~ "22222222"
    end

    test "approve removes member from the list", %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "Alice", ieee_membership_number: "97775577"})

      {:ok, lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      assert html =~ "Alice"

      rendered =
        lv
        |> element(~s([phx-click="approve"]), "Approve")
        |> render_click()

      refute rendered =~ "Alice"
      assert rendered =~ "All caught up!"
    end

    test "approve creates registration for the current year even if member has not logged in since year change",
         %{conn: conn} do
      member = confirmed_member_fixture()
      create_member_info(member, %{first_name: "Alice", ieee_membership_number: "97775577"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/verification")

      lv
      |> element(~s([phx-click="approve"]), "Approve")
      |> render_click()

      registration = Members.get_registration(member.id, 2025)
      assert registration != nil
      assert registration.payment_override == true
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
