defmodule IeeeTamuPortal.Members.EventCheckinTest do
  use IeeeTamuPortal.DataCase

  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members.EventCheckin
  alias IeeeTamuPortal.Repo

  describe "member_is_checked_in?/1" do
    setup do
      case Repo.get_by(IeeeTamuPortal.Settings.Setting, key: "current_event") do
        nil -> :ok
        existing -> Repo.delete!(existing)
      end

      :ok
    end

    test "returns false when current event is the default" do
      member = member_fixture()
      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false when member is not checked in" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()
      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns true when member has an event checkin for current event and year" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_name: "general_meeting",
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?(member)
    end

    test "works with member id integer" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_name: "general_meeting",
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?(member.id)
    end

    test "works with member id binary string" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_name: "general_meeting",
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?("#{member.id}")
    end

    test "returns false when checkin is for different event" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_name: "other_event",
            event_year: 2024
          },
          on_conflict: :nothing
        )

      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false when checkin is for different year" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_name: "general_meeting",
            event_year: 2023
          },
          on_conflict: :nothing
        )

      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false for non-parseable binary id" do
      import IeeeTamuPortal.SettingsFixtures

      current_event_setting_fixture("general_meeting")
      registration_year_setting_fixture("2024")

      refute EventCheckin.member_is_checked_in?("not_a_number")
    end
  end
end
