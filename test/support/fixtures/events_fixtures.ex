defmodule IeeeTamuPortal.EventsFixtures do
  @moduledoc """
  Test helpers for creating events and the active event setting.
  """

  alias IeeeTamuPortal.{Events, Settings}

  def event_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        summary: "Test Event #{System.unique_integer([:positive])}",
        dtstart: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, event} = Events.create_event(attrs)
    event
  end

  def current_event_fixture(attrs \\ %{}) do
    event = event_fixture(attrs)
    {:ok, _event} = Settings.set_current_event_uid(event.uid)
    event
  end
end
