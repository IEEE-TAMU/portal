defmodule IeeeTamuPortal.Members.EventCheckin do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Events.Event

  schema "event_checkins" do
    field :event_name, :string

    field :event_year, :integer,
      autogenerate: {IeeeTamuPortal.Settings, :get_registration_year!, []}

    belongs_to :member, IeeeTamuPortal.Accounts.Member

    belongs_to :event, Event,
      references: :uid,
      foreign_key: :event_uid,
      type: Ecto.UUID

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event_checkin, attrs) do
    event_checkin
    |> cast(attrs, [:member_id, :event_uid, :event_name, :event_year])
    |> validate_required([:event_uid, :event_name, :event_year, :member_id])
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:event_uid)
    |> unique_constraint([:member_id, :event_uid, :event_year])
  end

  @doc """
  Inserts a check-in for the given member id against the active event.

  The event uid is authoritative; `event_name` is kept as a display snapshot.
  Idempotent across the composite key; safe to call multiple times.
  """
  def insert_for_member_id(member_id) when is_integer(member_id) or is_binary(member_id) do
    case IeeeTamuPortal.Settings.current_event() do
      nil ->
        {:error, :no_current_event}

      %Event{} = event ->
        attrs = %{
          member_id: member_id,
          event_uid: event.uid,
          event_name: event.summary,
          event_year: IeeeTamuPortal.Settings.get_registration_year!()
        }

        %__MODULE__{}
        |> changeset(attrs)
        |> IeeeTamuPortal.Repo.insert(on_conflict: :nothing)
    end
  end

  @doc """
  Returns list of {created, email, uin, event_title} tuples for all check-ins in
  the given year. Titles come from the linked event.

  Used by admin CSV export.
  """
  def emails_and_event_names_for_year(year) when is_integer(year) do
    from(c in __MODULE__,
      join: m in assoc(c, :member),
      join: i in assoc(m, :info),
      join: e in Event,
      on: e.uid == c.event_uid,
      where: c.event_year == ^year,
      select: {c.inserted_at, m.email, i.uin, e.summary},
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns list of {created, email, uin, event_title} tuples for check-ins in the
  given year for a specific event uid.
  """
  def emails_and_event_names_for_year(year, event_uid)
      when is_integer(year) and is_binary(event_uid) do
    from(c in __MODULE__,
      join: m in assoc(c, :member),
      join: i in assoc(m, :info),
      join: e in Event,
      on: e.uid == c.event_uid,
      where: c.event_year == ^year and c.event_uid == ^event_uid,
      select: {c.inserted_at, m.email, i.uin, e.summary},
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the count of check-ins for the given year.
  """
  def count_for_year(year) when is_integer(year) do
    from(e in __MODULE__, where: e.event_year == ^year, select: count(e.id))
    |> Repo.one()
  end

  @doc """
  Lists distinct real events that have check-ins in the given year.
  """
  def list_events_for_year(year) when is_integer(year) do
    from(c in __MODULE__,
      join: e in Event,
      on: e.uid == c.event_uid,
      where: c.event_year == ^year,
      distinct: true,
      order_by: e.summary,
      select: %{uid: e.uid, summary: e.summary}
    )
    |> Repo.all()
  end

  @doc """
  Returns true if the member has an EventCheckin for the current event and registration year.

  Accepts a Member struct or a member id.
  If no event is active, this always returns false.
  """
  def member_is_checked_in?(%IeeeTamuPortal.Accounts.Member{id: id}),
    do: member_is_checked_in?(id)

  def member_is_checked_in?(member_id) when is_integer(member_id) or is_binary(member_id) do
    case IeeeTamuPortal.Settings.current_event() do
      nil ->
        false

      %Event{uid: event_uid} ->
        event_year = IeeeTamuPortal.Settings.get_registration_year!()

        member_id =
          case member_id do
            id when is_integer(id) ->
              id

            bin when is_binary(bin) ->
              case Integer.parse(bin) do
                {int, _} -> int
                :error -> -1
              end
          end

        query =
          from ec in __MODULE__,
            where:
              ec.member_id == ^member_id and ec.event_uid == ^event_uid and
                ec.event_year == ^event_year,
            select: 1,
            limit: 1

        Repo.exists?(query)
    end
  end
end
