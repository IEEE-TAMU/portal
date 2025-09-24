defmodule IeeeTamuPortal.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Events.Event
  alias IeeeTamuPortal.Events.RSVP

  @doc """
  Returns events, filtered and ordered.

  Options:
  - `:after` (DateTime or Date): default `DateTime.utc_now()`; returns events that overlap or occur after this moment.

  Overlap semantics ensure currently-running events are included.
  """
  def list_events(opts \\ []) do
    cutoff =
      case Keyword.get(opts, :after, DateTime.utc_now()) do
        %DateTime{} = dt -> dt
        %Date{} = d -> DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
        other when is_binary(other) -> other |> DateTime.from_iso8601() |> elem(1)
        _ -> DateTime.utc_now()
      end

    query =
      from e in Event,
        where:
          (is_nil(e.dtend) and e.dtstart >= ^cutoff) or
            (not is_nil(e.dtend) and e.dtend >= ^cutoff),
        order_by: [desc: e.dtstart]

    Repo.all(query)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(uid), do: Repo.get!(Event, uid)

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Returns the count of events.

  ## Examples

      iex> count_events()
      5

  """
  def count_events do
    Repo.aggregate(Event, :count, :uid)
  end

  def next_event do
    from(e in Event,
      where: e.dtstart >= ^DateTime.utc_now(),
      order_by: [asc: e.dtstart],
      limit: 1
    )
    |> Repo.one()
  end

  # RSVP Functions

  @doc """
  Creates an RSVP for a member to an event.
  """
  def create_rsvp(member_id, event_uid) do
    attrs = %{member_id: member_id, event_uid: event_uid}

    %RSVP{}
    |> RSVP.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an RSVP for a member to an event.
  """
  def delete_rsvp(member_id, event_uid) do
    case get_rsvp(member_id, event_uid) do
      nil -> {:error, :not_found}
      rsvp -> Repo.delete(rsvp)
    end
  end

  @doc """
  Gets an RSVP for a member to an event.
  """
  def get_rsvp(member_id, event_uid) do
    from(r in RSVP,
      where: r.member_id == ^member_id and r.event_uid == ^event_uid
    )
    |> Repo.one()
  end

  @doc """
  Checks if a member has RSVPed to an event.
  """
  def member_rsvped?(member_id, event_uid) do
    get_rsvp(member_id, event_uid) != nil
  end

  @doc """
  Gets the count of RSVPs for an event.
  """
  def count_rsvps(event_uid) do
    from(r in RSVP, where: r.event_uid == ^event_uid)
    |> Repo.aggregate(:count)
  end

  @doc """
  Checks if an event is at capacity based on its RSVP limit.
  """
  def event_at_capacity?(event_uid) do
    event = get_event!(event_uid)

    case event.rsvp_limit do
      nil -> false
      limit -> count_rsvps(event_uid) >= limit
    end
  end

  @doc """
  Gets event with RSVP information for a specific member.
  """
  def get_event_with_rsvp_info(event_uid, member_id) do
    event = get_event!(event_uid)
    rsvp_count = count_rsvps(event_uid)
    member_rsvped = member_rsvped?(member_id, event_uid)

    at_capacity =
      case event.rsvp_limit do
        nil -> false
        limit -> rsvp_count >= limit
      end

    %{
      event: event,
      rsvp_count: rsvp_count,
      member_rsvped: member_rsvped,
      at_capacity: at_capacity
    }
  end

  @doc """
  Gets a list of RSVPs for an event with member details.
  Returns a list of maps with member information.
  """
  def list_event_rsvps(event_uid) do
    from(r in RSVP,
      join: m in assoc(r, :member),
      join: i in assoc(m, :info),
      where: r.event_uid == ^event_uid,
      select: %{
        rsvp_id: r.id,
        member_id: m.id,
        first_name: i.first_name,
        last_name: i.last_name,
        preferred_name: i.preferred_name,
        email: m.email,
        inserted_at: r.inserted_at
      },
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a list of checkins for an event (by event name) with member details.
  Returns a list of maps with member information.
  """
  def list_event_checkins(event_name, year \\ nil) do
    year = year || IeeeTamuPortal.Settings.get_registration_year!()

    from(c in IeeeTamuPortal.Members.EventCheckin,
      join: m in assoc(c, :member),
      join: i in assoc(m, :info),
      where: c.event_name == ^event_name and c.event_year == ^year,
      select: %{
        checkin_id: c.id,
        member_id: m.id,
        first_name: i.first_name,
        last_name: i.last_name,
        preferred_name: i.preferred_name,
        email: m.email,
        inserted_at: c.inserted_at
      },
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets the count of checkins for an event (by event name).
  """
  def count_event_checkins(event_name, year \\ nil) do
    year = year || IeeeTamuPortal.Settings.get_registration_year!()

    from(c in IeeeTamuPortal.Members.EventCheckin,
      where: c.event_name == ^event_name and c.event_year == ^year
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets emails and names for RSVPs of a specific event for CSV export.
  Returns a list of {email, name, event_title} tuples.
  """
  def emails_and_names_for_event_rsvps(event_uid) do
    from(r in RSVP,
      join: m in assoc(r, :member),
      join: i in assoc(m, :info),
      join: e in assoc(r, :event),
      where: r.event_uid == ^event_uid,
      select: {
        m.email,
        fragment(
          "COALESCE(NULLIF(?, ''), CONCAT(?, ' ', ?))",
          i.preferred_name,
          i.first_name,
          i.last_name
        ),
        e.summary
      },
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets emails and names for checkins of a specific event for CSV export.
  Returns a list of {email, name, event_name} tuples.
  """
  def emails_and_names_for_event_checkins(event_name, year \\ nil) do
    year = year || IeeeTamuPortal.Settings.get_registration_year!()

    from(c in IeeeTamuPortal.Members.EventCheckin,
      join: m in assoc(c, :member),
      join: i in assoc(m, :info),
      where: c.event_name == ^event_name and c.event_year == ^year,
      select: {
        m.email,
        fragment(
          "COALESCE(NULLIF(?, ''), CONCAT(?, ' ', ?))",
          i.preferred_name,
          i.first_name,
          i.last_name
        ),
        c.event_name
      },
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end
end
