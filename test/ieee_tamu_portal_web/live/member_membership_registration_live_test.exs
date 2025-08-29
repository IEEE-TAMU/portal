defmodule IeeeTamuPortalWeb.MemberMembershipRegistrationLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures
  import IeeeTamuPortal.MembersFixtures

  alias IeeeTamuPortal.{Members, Settings}

  setup %{conn: conn} do
    # Ensure a known registration year
    registration_year_setting_fixture("2025")

    # Use a confirmed member and ensure info is present to pass on_mount checks
    member = confirmed_member_fixture()

    # Create required member info so :ensure_info_submitted passes
    {:ok, _info} =
      Members.create_member_info(member, %{
        uin: 123_001_234,
        first_name: "Test",
        last_name: "User",
        tshirt_size: :M,
        graduation_year: 2026,
        major: :ELEN,
        gender: :Male,
        international_student: false,
        phone_number: "123-456-7890"
      })

    {:ok, conn: log_in_member(conn, member), member: member}
  end

  describe "/members/registration" do
    test "shows pending status when no payment and no override", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Payment Pending"
      assert html =~ "Confirmation Code"
      # Ensure the actual confirmation code value is present in the page
      assert html =~ registration.confirmation_code
    end

    test "shows paid details when payment exists", %{conn: conn, member: member} do
      payment = payment_fixture(member)

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Registration Complete!"
      assert html =~ "Amount Paid"
      assert html =~ "Flywire Order ID"
      assert html =~ payment.id
    end

    test "shows override notice when payment is overridden", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)
      {:ok, _updated} = Members.update_registration(registration, %{payment_override: true})

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Registration Complete!"
      assert html =~ "Payment Override Applied"
      refute html =~ "Amount Paid"
    end
  end
end
