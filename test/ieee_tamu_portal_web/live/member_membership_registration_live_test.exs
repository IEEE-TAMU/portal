defmodule IeeeTamuPortalWeb.MemberMembershipRegistrationLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures
  import IeeeTamuPortal.MembersFixtures

  alias IeeeTamuPortal.{Members, Settings, Events}

  describe "/members/registration" do
    setup %{conn: conn} do
      registration_year_setting_fixture("2025")

      member = confirmed_member_fixture()

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

    test "shows pending status when no payment and no override", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Payment Pending"
      assert html =~ "Confirmation Code"
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

    test "shows upcoming events section for paid members", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)
      {:ok, _updated} = Members.update_registration(registration, %{payment_override: true})

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Upcoming Events"
      assert html =~ "Next 7 days"
    end

    test "RSVP event in upcoming events", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)
      {:ok, _updated} = Members.update_registration(registration, %{payment_override: true})

      _event =
        Events.create_event(%{
          dtstart:
            DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
          dtend: DateTime.utc_now() |> DateTime.add(7200, :second) |> DateTime.truncate(:second),
          summary: "RSVP Event",
          description: "Test RSVP Event",
          location: "ZACH 100",
          organizer: "IEEE TAMU",
          rsvpable: true
        })

      {:ok, lv, _html} = live(conn, ~p"/members/registration")

      lv
      |> element(~s(button[phx-click=toggle_upcoming_events]))
      |> render_click()

      html = render(lv)
      assert html =~ "RSVP Event"
      assert html =~ "RSVP"
    end

    test "shows check-in QR for paid members with active event", %{conn: conn, member: member} do
      year = Settings.get_registration_year!()
      {:ok, registration} = Members.get_or_create_registration(member, year)
      {:ok, _updated} = Members.update_registration(registration, %{payment_override: true})

      current_event_setting_fixture("active_event")

      {:ok, _lv, html} = live(conn, ~p"/members/registration")

      assert html =~ "Event Check-in QR"
      assert html =~ "checkin-qrcode"
    end
  end

  describe "unauthenticated" do
    test "redirects if not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/members/registration")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/members/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end
end
