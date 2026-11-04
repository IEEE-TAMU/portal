defmodule IeeeTamuPortal.Repo.Migrations.BackfillEventCheckinsEventUid.Checkin do
  use Ecto.Schema

  schema "event_checkins" do
    field(:event_name, :string)
    field(:event_year, :integer)
    field(:event_uid, Ecto.UUID)
    field(:member_id, :integer)

    timestamps(type: :utc_datetime)
  end
end

defmodule IeeeTamuPortal.Repo.Migrations.BackfillEventCheckinsEventUid.Event do
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

defmodule IeeeTamuPortal.Repo.Migrations.BackfillEventCheckinsEventUid do
  use Ecto.Migration
  import Ecto.Query

  alias IeeeTamuPortal.Repo.Migrations.BackfillEventCheckinsEventUid.Checkin
  alias IeeeTamuPortal.Repo.Migrations.BackfillEventCheckinsEventUid.Event

  def up do
    create_placeholders_for_unmatched_checkins()
    backfill_event_checkins()
    ensure_all_checkins_have_an_event!()

    alter table(:event_checkins) do
      modify :event_uid, :uuid, null: false
    end

    create unique_index(:event_checkins, [:member_id, :event_uid, :event_year],
             name: :event_checkins_member_id_event_uid_event_year_index
           )

    drop unique_index(:event_checkins, [:member_id, :event_name, :event_year])

    execute """
    ALTER TABLE event_checkins
      ADD CONSTRAINT event_checkins_event_uid_fkey
      FOREIGN KEY (event_uid) REFERENCES events(uid)
      ON DELETE RESTRICT ON UPDATE RESTRICT
    """
  end

  def down do
    execute """
    ALTER TABLE event_checkins
      DROP FOREIGN KEY event_checkins_event_uid_fkey
    """

    drop unique_index(:event_checkins, [:member_id, :event_uid, :event_year],
           name: :event_checkins_member_id_event_uid_event_year_index
         )

    alter table(:event_checkins) do
      modify :event_uid, :uuid, null: true
    end

    create unique_index(:event_checkins, [:member_id, :event_name, :event_year])
  end

  # Historical ad-hoc check-ins only have a name. Give each one a real private
  # event so the rest of the application can use event uids exclusively.
  defp create_placeholders_for_unmatched_checkins do
    from(c in Checkin,
      where: is_nil(c.event_uid),
      distinct: true,
      select: c.event_name
    )
    |> repo().all()
    |> Enum.each(&create_placeholder_if_unmatched/1)
  end

  defp create_placeholder_if_unmatched(event_name) do
    if repo().exists?(from(e in Event, where: e.summary == ^event_name)) do
      :ok
    else
      first_checkin =
        repo().one(
          from(c in Checkin,
            where: is_nil(c.event_uid) and c.event_name == ^event_name,
            select: min(c.inserted_at)
          )
        )

      summary = if event_name in [nil, ""], do: "Legacy check-in", else: event_name

      event =
        repo().insert!(%Event{
          uid: Ecto.UUID.generate(),
          summary: summary,
          description: "Created while migrating historical ad-hoc check-ins to event uids",
          dtstart: first_checkin || DateTime.utc_now() |> DateTime.truncate(:second),
          private: true,
          rsvpable: false
        })

      from(c in Checkin,
        where: is_nil(c.event_uid) and c.event_name == ^event_name
      )
      |> repo().update_all(set: [event_uid: event.uid])
    end
  end

  defp backfill_event_checkins do
    from(c in Checkin, where: is_nil(c.event_uid))
    |> repo().all()
    |> Enum.each(&backfill_row/1)
  end

  defp backfill_row(checkin) do
    events =
      repo().all(from(e in Event, where: e.summary == ^checkin.event_name))

    case events do
      [] ->
        :ok

      events ->
        event =
          Enum.min_by(events, fn event ->
            {abs(DateTime.diff(event.dtstart, checkin.inserted_at, :second)), event.uid}
          end)

        from(c in Checkin, where: c.id == ^checkin.id)
        |> repo().update_all(set: [event_uid: event.uid])
    end
  end

  defp ensure_all_checkins_have_an_event! do
    if repo().exists?(from(c in Checkin, where: is_nil(c.event_uid))) do
      raise "event_checkins contains rows that could not be mapped to an event"
    end
  end
end
