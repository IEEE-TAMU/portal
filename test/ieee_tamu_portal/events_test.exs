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

    test "list_events/0 returns events ordered by dtstart desc" do
      {:ok, e1} =
        Events.create_event(
          valid_attrs(%{dtstart: DateTime.add(DateTime.utc_now(), -7200, :second)})
        )

      {:ok, e2} =
        Events.create_event(
          valid_attrs(%{dtstart: DateTime.add(DateTime.utc_now(), -3600, :second)})
        )

      assert [e2.uid, e1.uid] == Events.list_events() |> Enum.map(& &1.uid)
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
  end
end
