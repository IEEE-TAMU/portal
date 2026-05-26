defmodule IeeeTamuPortal.Mautic.ContactSyncTest do
  use IeeeTamuPortal.DataCase

  import ExUnit.CaptureLog

  alias IeeeTamuPortal.Mautic.ContactSync
  alias IeeeTamuPortal.{Accounts, Members}
  alias IeeeTamuPortal.Accounts.Member

  import IeeeTamuPortal.AccountsFixtures

  describe "transform_member_to_contact/1" do
    test "returns nil for member without email" do
      member = member_without_email()

      assert ContactSync.transform_member_to_contact(member) == nil
    end

    test "returns basic contact for member without info" do
      member = member_fixture()

      contact = ContactSync.transform_member_to_contact(member)

      assert contact["email"] == member.email
      assert contact["tags"] == ["portal-upload"]
      refute Map.has_key?(contact, "firstname")
    end

    test "maps all info fields correctly" do
      member = member_fixture() |> with_full_info()

      contact = ContactSync.transform_member_to_contact(member)

      assert contact["email"] == member.email
      assert contact["firstname"] == member.info.preferred_name
      assert contact["lastname"] == member.info.last_name
      assert contact["major"] == to_string(member.info.major)
      assert contact["graduation_year"] == to_string(member.info.graduation_year)
      assert contact["tshirt_size"] == to_string(member.info.tshirt_size)
      assert contact["uin"] == to_string(member.info.uin)
      assert contact["tags"] == ["portal-upload"]
    end

    test "prefers preferred_name over first_name" do
      member = member_fixture() |> with_full_info(%{preferred_name: "Johnny", first_name: "John"})

      contact = ContactSync.transform_member_to_contact(member)
      assert contact["firstname"] == "Johnny"
    end

    test "falls back to first_name when no preferred_name" do
      member = member_fixture() |> with_full_info(%{preferred_name: nil, first_name: "Jane"})

      contact = ContactSync.transform_member_to_contact(member)
      assert contact["firstname"] == "Jane"
    end

    test "includes timestamps when present" do
      member = member_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Repo.update!(Ecto.Changeset.change(member, confirmed_at: now))
      member = Accounts.get_member_with_info(member.id)

      contact = ContactSync.transform_member_to_contact(member)
      assert contact["confirmed_at"]
      assert contact["member_since"]
    end

    test "omits confirmed_at when nil" do
      member = member_fixture()

      contact = ContactSync.transform_member_to_contact(member)
      refute Map.has_key?(contact, "confirmed_at")
    end
  end

  describe "sync_member/1" do
    test "returns {:ok, :skipped_not_found} for non-existent member id" do
      capture_log(fn ->
        assert ContactSync.sync_member(0) == {:ok, :skipped_not_found}
      end)
    end

    test "returns {:ok, :skipped_no_email} for member without email" do
      member = member_without_email()

      capture_log(fn ->
        assert ContactSync.sync_member(member) == {:ok, :skipped_no_email}
      end)
    end
  end

  defp member_without_email do
    %Member{email: ""}
  end

  defp with_full_info(member, overrides \\ %{}) do
    defaults = %{
      first_name: "Test",
      last_name: "User",
      preferred_name: "Test",
      uin: 123_004_567,
      tshirt_size: :M,
      major: :CSCE,
      graduation_year: 2026,
      gender: :Male,
      international_student: false
    }

    attrs = Map.merge(defaults, overrides)
    {:ok, _info} = Members.create_member_info(member, attrs)
    Repo.preload(member, :info)
  end
end
