defmodule IeeeTamuPortal.Services.MembershipServiceTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Services.MembershipService
  alias IeeeTamuPortal.{Accounts, Members}

  import IeeeTamuPortal.AccountsFixtures

  describe "update_or_create_member_info/2" do
    test "creates member info when none exists" do
      member = member_fixture()

      info_params = %{
        first_name: "John",
        last_name: "Doe",
        # Valid UIN format XXX00XXXX
        uin: 123_004_567,
        major: :CPEN,
        graduation_year: 2025,
        tshirt_size: :M,
        gender: :Male,
        international_student: false
      }

      assert {:ok, info} = MembershipService.update_or_create_member_info(member, info_params)
      assert info.first_name == "John"
      assert info.last_name == "Doe"
      assert info.member_id == member.id
    end

    test "updates existing member info" do
      member = member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          first_name: "Jane",
          last_name: "Smith",
          # Valid UIN format
          uin: 987_004_321,
          major: :ELEN,
          graduation_year: 2024,
          tshirt_size: :S,
          gender: :Female,
          international_student: false
        })

      member = Accounts.preload_member_info(member)

      update_params = %{first_name: "Janet", graduation_year: 2026}

      assert {:ok, updated_info} =
               MembershipService.update_or_create_member_info(member, update_params)

      assert updated_info.first_name == "Janet"
      # unchanged
      assert updated_info.last_name == "Smith"
      assert updated_info.graduation_year == 2026
    end

    test "returns error with invalid data" do
      member = member_fixture()

      invalid_params = %{uin: "not_a_number"}

      assert {:error, changeset} =
               MembershipService.update_or_create_member_info(member, invalid_params)

      assert changeset.errors[:uin]
    end
  end

  describe "get_member_payment_status/2" do
    test "returns unpaid status when no registration exists" do
      member = member_fixture()

      status = MembershipService.get_member_payment_status(member, 2024)

      assert status.has_paid == false
      assert status.has_override == false
    end

    test "returns paid status with override" do
      member = member_fixture()
      {:ok, registration} = Members.create_registration(member, %{year: 2024})

      {:ok, _updated_registration} =
        Members.update_registration(registration, %{payment_override: true})

      status = MembershipService.get_member_payment_status(member, 2024)

      assert status.has_paid == true
      assert status.has_override == true
    end

    test "returns paid status with actual payment" do
      member = member_fixture()
      {:ok, registration} = Members.create_registration(member, %{year: 2024})

      {:ok, _payment} =
        Members.create_payment(%{
          id: "test123",
          amount: Decimal.new("25.00"),
          confirmation_code: registration.confirmation_code,
          tshirt_size: :M,
          name: "Test Member",
          registration_id: registration.id
        })

      status = MembershipService.get_member_payment_status(member, 2024)

      assert status.has_paid == true
      assert status.has_override == false
    end
  end

  describe "update_member_payment_status/3" do
    test "toggles payment override successfully" do
      member = member_fixture()

      assert {:ok, registration} =
               MembershipService.update_member_payment_status(member, 2024, :toggle_override)

      assert registration.payment_override == true

      # Toggle again
      assert {:ok, registration} =
               MembershipService.update_member_payment_status(member, 2024, :toggle_override)

      assert registration.payment_override == false
    end

    test "creates registration if none exists when toggling override" do
      member = member_fixture()

      # Verify no registration exists
      assert Members.get_registration(member.id, 2024) == nil

      assert {:ok, registration} =
               MembershipService.update_member_payment_status(member, 2024, :toggle_override)

      assert registration.payment_override == true
      assert registration.member_id == member.id
      assert registration.year == 2024
    end
  end
end
