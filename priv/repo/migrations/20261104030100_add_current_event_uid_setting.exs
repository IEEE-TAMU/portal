defmodule IeeeTamuPortal.Repo.Migrations.AddCurrentEventUidSetting.Event do
  use Ecto.Schema

  @primary_key {:uid, Ecto.UUID, autogenerate: false}
  schema "events" do
    field(:dtstart, :utc_datetime)
    field(:dtend, :utc_datetime)
    field(:summary, :string)
    field(:description, :string)
    field(:private, :boolean, default: false)
    field(:rsvpable, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end
end

defmodule IeeeTamuPortal.Repo.Migrations.AddCurrentEventUidSetting.Setting do
  use Ecto.Schema

  schema "settings" do
    field(:key, :string)
    field(:value, :string)
    field(:description, :string)

    timestamps(type: :utc_datetime)
  end
end

defmodule IeeeTamuPortal.Repo.Migrations.AddCurrentEventUidSetting do
  use Ecto.Migration
  import Ecto.Query

  alias IeeeTamuPortal.Repo.Migrations.AddCurrentEventUidSetting.Event
  alias IeeeTamuPortal.Repo.Migrations.AddCurrentEventUidSetting.Setting

  @legacy_stopped_value "NONE"

  def up do
    if is_nil(repo().get_by(Setting, key: "current_event_uid")) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      legacy = repo().get_by(Setting, key: "current_event")
      uid = resolve_uid(legacy && legacy.value, now)

      if uid do
        repo().insert_all(Setting, [
          %{
            key: "current_event_uid",
            value: uid,
            description: "Current active event uid",
            inserted_at: now,
            updated_at: now
          }
        ])
      end
    end

    repo().delete_all(from(s in Setting, where: s.key == "current_event"))
  end

  def down do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    repo().delete_all(from(s in Setting, where: s.key == "current_event_uid"))

    repo().insert_all(Setting, [
      %{
        key: "current_event",
        value: @legacy_stopped_value,
        description: "Current active event",
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  defp resolve_uid(value, _now) when value in [nil, "", @legacy_stopped_value],
    do: nil

  defp resolve_uid(summary, now) do
    events =
      repo().all(from(e in Event, where: e.summary == ^summary))

    case pick_event(events, now) do
      nil -> create_placeholder_event(summary, now).uid
      event -> event.uid
    end
  end

  defp pick_event([], _now), do: nil

  defp pick_event(events, now) do
    active =
      events
      |> Enum.filter(&active?(&1, now))
      |> Enum.max_by(&{unix_microsecond(&1.dtstart), &1.uid}, fn -> nil end)

    active || next_or_latest(events, now)
  end

  defp active?(%Event{dtstart: dtstart, dtend: dtend}, now) do
    started? = not is_nil(dtstart) and DateTime.compare(dtstart, now) != :gt
    ended? = not is_nil(dtend) and DateTime.compare(dtend, now) == :lt
    started? and not ended?
  end

  defp next_or_latest(events, now) do
    future =
      events
      |> Enum.filter(&(&1.dtstart && DateTime.compare(&1.dtstart, now) != :lt))
      |> Enum.min_by(&{unix_microsecond(&1.dtstart), &1.uid}, fn -> nil end)

    future || Enum.max_by(events, &{unix_microsecond(&1.dtstart), &1.uid})
  end

  defp unix_microsecond(nil), do: 0
  defp unix_microsecond(%DateTime{} = dt), do: DateTime.to_unix(dt, :microsecond)

  defp create_placeholder_event(summary, now) do
    repo().insert!(%Event{
      uid: Ecto.UUID.generate(),
      summary: summary,
      description: "Created while migrating the legacy current_event setting to an event uid",
      dtstart: now,
      private: true,
      rsvpable: false
    })
  end
end
