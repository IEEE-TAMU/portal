defmodule IeeeTamuPortal.Members.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payments" do
    field :name, :string
    field :amount, :decimal
    field :confirmation_code, :string
    field :tshirt_size, Ecto.Enum, values: ~w(S M L XL XXL)a
    field :contact_email, :string

    belongs_to :registration, IeeeTamuPortal.Members.Registration

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:amount, :confirmation_code, :tshirt_size, :contact_email, :name])
    |> validate_required([:amount, :confirmation_code, :tshirt_size, :contact_email, :name])
    |> validate_format(:contact_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email"
    )
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:confirmation_code)
  end
end
