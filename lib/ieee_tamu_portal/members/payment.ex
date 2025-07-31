defmodule IeeeTamuPortal.Members.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "payments" do
    field :id, :string, primary_key: true, source: :order_id
    field :name, :string
    field :amount, :decimal
    field :confirmation_code, :string
    field :tshirt_size, Ecto.Enum, values: ~w(S M L XL XXL)a

    belongs_to :registration, IeeeTamuPortal.Members.Registration

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:id, :amount, :confirmation_code, :tshirt_size, :name])
    |> validate_required([:id, :amount, :tshirt_size, :name])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> unique_constraint(:id)
  end

  def registration_changeset(payment, attrs) do
    payment
    |> cast(attrs, [:registration_id])
    |> validate_required([:registration_id])
    |> foreign_key_constraint(:registration_id)
  end
end
