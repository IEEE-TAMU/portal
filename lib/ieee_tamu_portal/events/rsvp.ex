defmodule IeeeTamuPortal.Events.RSVP do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rsvps" do
    timestamps(type: :utc_datetime)

    belongs_to :member, IeeeTamuPortal.Accounts.Member

    belongs_to :event, IeeeTamuPortal.Events.Event,
      references: :uid,
      foreign_key: :event_uid,
      type: Ecto.UUID
  end

  @doc false
  def changeset(rsvp, attrs) do
    rsvp
    |> cast(attrs, [:member_id, :event_uid])
    |> validate_required([:member_id, :event_uid])
    |> unique_constraint([:member_id, :event_uid],
      message: "You have already RSVPed to this event"
    )
    |> foreign_key_constraint(:member_id, message: "Member not found")
    |> foreign_key_constraint(:event_uid, message: "Event not found")
  end
end
