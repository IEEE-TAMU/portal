defmodule IeeeTamuPortal.Members.EventCheckinTest do
  use IeeeTamuPortal.DataCase

  import Ecto.Query
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.EventsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Members.EventCheckin
  alias IeeeTamuPortal.Repo

  describe "member_is_checked_in?/1" do
    setup do
      Repo.delete_all(
        from(s in IeeeTamuPortal.Settings.Setting,
          where: s.key in ["current_event", "current_event_uid"]
        )
      )

      :ok
    end

    test "returns false when no current event is set" do
      member = member_fixture()
      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false when member is not checked in" do
      _event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()
      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns true when member has an event checkin for current event and year" do
      event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_uid: event.uid,
            event_name: event.summary,
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?(member)
    end

    test "works with member id integer" do
      event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_uid: event.uid,
            event_name: event.summary,
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?(member.id)
    end

    test "works with member id binary string" do
      event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_uid: event.uid,
            event_name: event.summary,
            event_year: 2024
          },
          on_conflict: :nothing
        )

      assert EventCheckin.member_is_checked_in?("#{member.id}")
    end

    test "returns false when checkin is for a different event with the same title" do
      _current = current_event_fixture(%{summary: "general_meeting"})
      other = event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_uid: other.uid,
            event_name: other.summary,
            event_year: 2024
          },
          on_conflict: :nothing
        )

      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false when checkin is for different year" do
      event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      {:ok, _} =
        Repo.insert(
          %EventCheckin{
            member_id: member.id,
            event_uid: event.uid,
            event_name: event.summary,
            event_year: 2023
          },
          on_conflict: :nothing
        )

      refute EventCheckin.member_is_checked_in?(member)
    end

    test "returns false for non-parseable binary id" do
      _event = current_event_fixture(%{summary: "general_meeting"})
      registration_year_setting_fixture("2024")

      refute EventCheckin.member_is_checked_in?("not_a_number")
    end
  end

  describe "insert_for_member_id/1" do
    test "stores the active event uid and title snapshot" do
      event = current_event_fixture(%{summary: "ad_hoc_event"})
      registration_year_setting_fixture("2024")

      member = member_fixture()

      assert {:ok, checkin} = EventCheckin.insert_for_member_id(member.id)
      assert checkin.event_uid == event.uid
      assert checkin.event_name == "ad_hoc_event"
      assert checkin.event_year == 2024
    end

    test "returns an error when no event is active" do
      Repo.delete_all(
        from(s in IeeeTamuPortal.Settings.Setting,
          where: s.key in ["current_event", "current_event_uid"]
        )
      )

      member = member_fixture()

      assert {:error, :no_current_event} = EventCheckin.insert_for_member_id(member.id)
    end
  end
end
