defmodule IeeeTamuPortal.Members.EventCheckin do
  use Ecto.Schema
  import Ecto.Changeset

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
end
