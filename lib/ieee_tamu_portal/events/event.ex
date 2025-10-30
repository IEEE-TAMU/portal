defmodule IeeeTamuPortal.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :uid}
  @primary_key {:uid, Ecto.UUID, autogenerate: true}
  @foreign_key_type :uuid
  schema "events" do
    field :dtstart, :utc_datetime
    field :dtend, :utc_datetime
    field :summary, :string
    field :description, :string
    field :location, :string
    field :organizer, :string
    field :rsvp_limit, :integer

    timestamps(type: :utc_datetime)

    has_many :rsvps, IeeeTamuPortal.Events.RSVP, on_delete: :delete_all
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:dtstart, :dtend, :summary, :description, :location, :organizer, :rsvp_limit])
    |> validate_required([:dtstart, :summary])
    |> validate_length(:summary, min: 1, max: 255)
    |> validate_length(:description, max: 10000)
    |> validate_length(:location, max: 255)
    |> validate_length(:organizer, max: 255)
    |> validate_number(:rsvp_limit, greater_than: 0)
    |> validate_rsvp_limit_against_current(attrs)
    |> validate_datetime_order()
  end

  defp validate_rsvp_limit_against_current(changeset, attrs) do
    case Map.get(attrs, "rsvp_limit_error") do
      nil -> changeset
      error_msg -> add_error(changeset, :rsvp_limit, error_msg)
    end
  end

  defp validate_datetime_order(changeset) do
    dtstart = get_field(changeset, :dtstart)
    dtend = get_field(changeset, :dtend)

    if dtstart && dtend && DateTime.compare(dtstart, dtend) == :gt do
      add_error(changeset, :dtend, "must be after start time")
    else
      changeset
    end
  end
end
