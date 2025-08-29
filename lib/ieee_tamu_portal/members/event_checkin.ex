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
    |> cast(attrs, [:member_id])
    |> validate_required([:event_name, :event_year, :member_id])
    |> foreign_key_constraint(:member_id)
    |> unique_constraint([:member_id, :event_name, :event_year])
  end
end
