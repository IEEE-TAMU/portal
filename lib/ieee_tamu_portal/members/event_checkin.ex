defmodule IeeeTamuPortal.Members.EventCheckin do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias IeeeTamuPortal.Repo

  schema "event_checkins" do
    field :event_name, :string, autogenerate: {IeeeTamuPortal.Settings, :get_current_event!, []}

    field :event_year, :integer,
      autogenerate: {IeeeTamuPortal.Settings, :get_registration_year!, []}

    belongs_to :member, IeeeTamuPortal.Accounts.Member

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event_checkin, attrs) do
    event_checkin
    |> cast(attrs, [:member_id, :event_name, :event_year])
    |> validate_required([:event_name, :event_year, :member_id])
    |> foreign_key_constraint(:member_id)
    |> unique_constraint([:member_id, :event_name, :event_year])
  end

  @doc """
  Inserts a check-in for the given member id using current settings for
  event name and registration year.

  Idempotent across the composite key; safe to call multiple times.
  """
  def insert_for_member_id(member_id) when is_integer(member_id) or is_binary(member_id) do
    attrs = %{
      member_id: member_id,
      event_name: IeeeTamuPortal.Settings.get_current_event!(),
      event_year: IeeeTamuPortal.Settings.get_registration_year!()
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> IeeeTamuPortal.Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Returns list of {created, email, uin, event_name} tuples for all check-ins in the given year.

  Used by admin CSV export.
  """
  def emails_and_event_names_for_year(year) when is_integer(year) do
    from(e in __MODULE__,
      join: m in assoc(e, :member),
      join: i in assoc(m, :info),
      where: e.event_year == ^year,
      select: {
        e.inserted_at,
        m.email,
        i.uin,
        e.event_name
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns list of {created, email, uin, event_name} tuples for all check-ins in the given year for a specific event.
  """
  def emails_and_event_names_for_year(year, event_name)
      when is_integer(year) and is_binary(event_name) do
    from(e in __MODULE__,
      join: m in assoc(e, :member),
      join: i in assoc(m, :info),
      where: e.event_year == ^year and e.event_name == ^event_name,
      select: {e.inserted_at, m.email, i.uin, e.event_name}
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
  Lists distinct event names recorded for the given year.
  """
  def list_event_names_for_year(year) when is_integer(year) do
    from(e in __MODULE__,
      where: e.event_year == ^year,
      distinct: true,
      order_by: e.event_name,
      select: e.event_name
    )
    |> Repo.all()
  end

  @doc """
  Returns true if the member has an EventCheckin for the current event and registration year.

  Accepts a Member struct or a member id.
  If the current event is the default "NONE", this always returns false.
  """
  def member_is_checked_in?(%IeeeTamuPortal.Accounts.Member{id: id}),
    do: member_is_checked_in?(id)

  def member_is_checked_in?(member_id) when is_integer(member_id) or is_binary(member_id) do
    event_name = IeeeTamuPortal.Settings.get_current_event!()

    if event_name == IeeeTamuPortal.Settings.default_current_event() do
      false
    else
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
            ec.member_id == ^member_id and ec.event_name == ^event_name and
              ec.event_year == ^event_year,
          select: 1,
          limit: 1

      Repo.exists?(query)
    end
  end
end
