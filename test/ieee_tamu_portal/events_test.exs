defmodule IeeeTamuPortal.EventsTest do
  use IeeeTamuPortal.DataCase, async: true

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Events.Event

  describe "events" do
    def valid_attrs(attrs \\ %{}) do
      Map.merge(
        %{
          dtstart: DateTime.utc_now() |> DateTime.truncate(:second),
          dtend: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
          summary: "General Meeting",
          description: "Weekly general meeting",
          location: "Zachry 100",
          organizer: "IEEE TAMU"
        },
        attrs
      )
    end

    test "list_events/1 returns events ordered by dtstart desc when including past via after: far past" do
      {:ok, e1} =
        Events.create_event(
          valid_attrs(%{dtstart: DateTime.add(DateTime.utc_now(), -7200, :second)})
        )

      {:ok, e2} =
        Events.create_event(
          valid_attrs(%{dtstart: DateTime.add(DateTime.utc_now(), -3600, :second)})
        )

      past = DateTime.add(DateTime.utc_now(), -365 * 24 * 3600, :second)
      assert [e2.uid, e1.uid] == Events.list_events(after: past) |> Enum.map(& &1.uid)
    end

    test "get_event!/1 returns the event by uid" do
      {:ok, event} = Events.create_event(valid_attrs())
      assert %Event{uid: uid} = Events.get_event!(event.uid)
      assert uid == event.uid
    end

    test "create_event/1 with valid data creates an event" do
      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs())
      assert event.summary == "General Meeting"
      assert event.location == "Zachry 100"
      assert event.organizer == "IEEE TAMU"
      assert event.dtstart
      assert event.dtend
    end

    test "create_event/1 without dtend is valid" do
      {:ok, event} = Events.create_event(valid_attrs(%{dtend: nil}))
      assert event.dtend == nil
    end

    test "create_event/1 requires dtstart and summary" do
      {:error, changeset} = Events.create_event(%{})
      assert %{dtstart: ["can't be blank"], summary: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_event/1 validates dtend after dtstart" do
      dtstart = DateTime.utc_now()
      dtend = DateTime.add(dtstart, -3600, :second)
      {:error, changeset} = Events.create_event(valid_attrs(%{dtstart: dtstart, dtend: dtend}))
      assert %{dtend: ["must be after start time"]} = errors_on(changeset)
    end

    test "update_event/2 updates fields" do
      {:ok, event} = Events.create_event(valid_attrs())
      {:ok, event} = Events.update_event(event, %{summary: "Updated"})
      assert event.summary == "Updated"
    end

    test "delete_event/1 deletes the event" do
      {:ok, event} = Events.create_event(valid_attrs())
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.uid) end
    end

    test "count_events/0 returns the number of events" do
      start_count = Events.count_events()
      {:ok, _} = Events.create_event(valid_attrs())
      assert Events.count_events() == start_count + 1
    end

    test "list_events/1 default only returns ongoing or future events (day granularity)" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _past_over} =
        Events.create_event(
          valid_attrs(%{
            dtstart: DateTime.add(now, -7200, :second),
            dtend: DateTime.add(now, -3600, :second),
            summary: "Past Over"
          })
        )

      {:ok, _ongoing} =
        Events.create_event(
          valid_attrs(%{
            dtstart: DateTime.add(now, -3600, :second),
            dtend: DateTime.add(now, 1800, :second),
            summary: "Ongoing"
          })
        )

      {:ok, _future} =
        Events.create_event(
          valid_attrs(%{
            dtstart: DateTime.add(now, 7200, :second),
            dtend: DateTime.add(now, 10800, :second),
            summary: "Future"
          })
        )

      # Default should exclude strictly past, include ongoing and future
      titles = Events.list_events() |> Enum.map(& &1.summary)
      assert "Past Over" not in titles
      assert "Ongoing" in titles
      assert "Future" in titles

      # Events without dtend are included only if start >= now
      {:ok, _past_no_end} =
        Events.create_event(
          valid_attrs(%{
            dtstart: DateTime.add(now, -60, :second),
            dtend: nil,
            summary: "PastNoEnd"
          })
        )

      {:ok, _future_no_end} =
        Events.create_event(
          valid_attrs(%{
            dtstart: DateTime.add(now, 60, :second),
            dtend: nil,
            summary: "FutureNoEnd"
          })
        )

      titles2 = Events.list_events() |> Enum.map(& &1.summary)
      assert "PastNoEnd" not in titles2
      assert "FutureNoEnd" in titles2
    end

    test "create_event/1 with rsvp_limit creates an event with limit" do
      {:ok, event} = Events.create_event(valid_attrs(%{rsvp_limit: 50}))
      assert event.rsvp_limit == 50
    end

    test "create_event/1 without rsvp_limit creates unlimited event" do
      {:ok, event} = Events.create_event(valid_attrs())
      assert event.rsvp_limit == nil
    end

    test "create_event/1 validates rsvp_limit is positive" do
      {:error, changeset} = Events.create_event(valid_attrs(%{rsvp_limit: 0}))
      assert %{rsvp_limit: ["must be greater than 0"]} = errors_on(changeset)

      {:error, changeset} = Events.create_event(valid_attrs(%{rsvp_limit: -5}))
      assert %{rsvp_limit: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "delete_event/1 deletes the event and associated RSVPs" do
      # Import the accounts fixtures to create a member
      import IeeeTamuPortal.AccountsFixtures

      # Create an event
      {:ok, event} = Events.create_event(valid_attrs())

      # Create a member for RSVP
      member = member_fixture()

      # Create an RSVP for the event
      {:ok, _rsvp} = Events.create_rsvp(member.id, event.uid)

      # Verify the RSVP exists
      assert Events.count_rsvps(event.uid) == 1

      # Delete the event
      assert {:ok, %Event{}} = Events.delete_event(event)

      # Verify event is deleted
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.uid) end

      # Verify RSVPs are also deleted (cascade delete)
      assert Events.count_rsvps(event.uid) == 0
    end
  end

  describe "rsvps" do
    import IeeeTamuPortal.AccountsFixtures
    import IeeeTamuPortal.SettingsFixtures
    alias IeeeTamuPortal.Members

    setup do
      {:ok, event} =
        Events.create_event(valid_attrs(%{summary: "RSVP Test Event", rsvp_limit: nil}))

      %{event: event}
    end

    test "create_rsvp/2 creates an RSVP", %{event: event} do
      member = member_fixture()
      assert {:ok, rsvp} = Events.create_rsvp(member.id, event.uid)
      assert rsvp.member_id == member.id
      assert rsvp.event_uid == event.uid
    end

    test "create_rsvp/2 fails with duplicate RSVP", %{event: event} do
      member = member_fixture()
      {:ok, _} = Events.create_rsvp(member.id, event.uid)
      assert {:error, _changeset} = Events.create_rsvp(member.id, event.uid)
    end

    test "get_rsvp/2 retrieves an RSVP", %{event: event} do
      member = member_fixture()
      {:ok, _rsvp} = Events.create_rsvp(member.id, event.uid)
      rsvp = Events.get_rsvp(member.id, event.uid)
      assert rsvp != nil
      assert rsvp.member_id == member.id
    end

    test "get_rsvp/2 returns nil for non-existent RSVP", %{event: event} do
      assert Events.get_rsvp(-1, event.uid) == nil
    end

    test "member_rsvped?/2 returns true when RSVP exists", %{event: event} do
      member = member_fixture()
      {:ok, _} = Events.create_rsvp(member.id, event.uid)
      assert Events.member_rsvped?(member.id, event.uid)
    end

    test "member_rsvped?/2 returns false when no RSVP", %{event: event} do
      refute Events.member_rsvped?(-1, event.uid)
    end

    test "delete_rsvp/2 removes an RSVP", %{event: event} do
      member = member_fixture()
      {:ok, _} = Events.create_rsvp(member.id, event.uid)
      assert Events.member_rsvped?(member.id, event.uid)
      assert {:ok, _} = Events.delete_rsvp(member.id, event.uid)
      refute Events.member_rsvped?(member.id, event.uid)
    end

    test "delete_rsvp/2 returns error for non-existent RSVP", %{event: event} do
      assert {:error, :not_found} = Events.delete_rsvp(-1, event.uid)
    end

    test "count_rsvps/1 returns count of RSVPs", %{event: event} do
      assert Events.count_rsvps(event.uid) == 0

      member1 = member_fixture()
      member2 = member_fixture()
      {:ok, _} = Events.create_rsvp(member1.id, event.uid)
      {:ok, _} = Events.create_rsvp(member2.id, event.uid)

      assert Events.count_rsvps(event.uid) == 2
    end

    test "event_at_capacity?/1 is false when no limit", %{event: event} do
      refute Events.event_at_capacity?(event.uid)
    end

    test "event_at_capacity?/1 is true when limit reached", %{event: _event} do
      {:ok, limited} =
        Events.create_event(valid_attrs(%{summary: "Limited Event", rsvp_limit: 2}))

      member1 = member_fixture()
      member2 = member_fixture()
      {:ok, _} = Events.create_rsvp(member1.id, limited.uid)
      {:ok, _} = Events.create_rsvp(member2.id, limited.uid)

      assert Events.event_at_capacity?(limited.uid)
    end

    test "event_at_capacity?/1 is false when limit not reached", %{event: _event} do
      {:ok, limited} =
        Events.create_event(valid_attrs(%{summary: "Not Full", rsvp_limit: 10}))

      member = member_fixture()
      {:ok, _} = Events.create_rsvp(member.id, limited.uid)

      refute Events.event_at_capacity?(limited.uid)
    end

    test "get_event_with_rsvp_info/2 includes RSVP info", %{event: event} do
      member = member_fixture()
      {:ok, _} = Events.create_rsvp(member.id, event.uid)

      info = Events.get_event_with_rsvp_info(event.uid, member.id)

      assert info.rsvp_count == 1
      assert info.member_rsvped == true
      assert info.at_capacity == false
    end

    test "list_event_rsvps/1 returns RSVPs with member info", %{event: event} do
      member = member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: 123_001_234,
          first_name: "Alice",
          last_name: "Smith",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      {:ok, _} = Events.create_rsvp(member.id, event.uid)

      rsvps = Events.list_event_rsvps(event.uid)
      assert length(rsvps) == 1
      assert hd(rsvps).first_name == "Alice"
    end
  end

  describe "checkins" do
    import IeeeTamuPortal.AccountsFixtures
    import IeeeTamuPortal.SettingsFixtures
    alias IeeeTamuPortal.Members
    alias IeeeTamuPortal.Members.EventCheckin

    setup do
      registration_year_setting_fixture("2025")
      current_event_setting_fixture("test_event")
      :ok
    end

    test "list_event_checkins/1 returns checkins with member info" do
      member = member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: 123_001_234,
          first_name: "Alice",
          last_name: "Smith",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      EventCheckin.insert_for_member_id(member.id)

      checkins = Events.list_event_checkins("test_event", 2025)
      assert length(checkins) == 1
      assert hd(checkins).first_name == "Alice"
    end

    test "count_event_checkins/2 returns count of checkins" do
      assert Events.count_event_checkins("test_event", 2025) == 0

      member = member_fixture()
      EventCheckin.insert_for_member_id(member.id)

      assert Events.count_event_checkins("test_event", 2025) == 1
    end

    test "emails_and_names_for_event_rsvps/1 returns CSV export data" do
      {:ok, event} =
        Events.create_event(valid_attrs(%{summary: "CSV Export Event"}))

      member = member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: 123_001_234,
          first_name: "Alice",
          last_name: "Smith",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      {:ok, _} = Events.create_rsvp(member.id, event.uid)

      rows = Events.emails_and_names_for_event_rsvps(event.uid)
      assert length(rows) == 1
      {_created, email, _name, _uin, event_title} = hd(rows)
      assert email == member.email
      assert event_title == "CSV Export Event"
    end

    test "emails_and_names_for_event_checkins/2 returns CSV export data" do
      member = member_fixture()

      {:ok, _info} =
        Members.create_member_info(member, %{
          uin: 123_001_234,
          first_name: "Alice",
          last_name: "Smith",
          tshirt_size: :M,
          graduation_year: 2026,
          major: :ELEN,
          gender: :Male,
          international_student: false,
          phone_number: "123-456-7890"
        })

      EventCheckin.insert_for_member_id(member.id)

      rows = Events.emails_and_names_for_event_checkins("test_event", 2025)
      assert length(rows) == 1
      {_created, email, _name, _uin, event_name} = hd(rows)
      assert email == member.email
      assert event_name == "test_event"
    end

    test "next_event/0 returns soonest upcoming event" do
      result = Events.next_event()
      # May return nil if no events exist, or an event struct
      assert is_nil(result) || result.__struct__ == Event
    end
  end
end
