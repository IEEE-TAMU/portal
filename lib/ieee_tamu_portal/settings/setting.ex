defmodule IeeeTamuPortal.Settings.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :value, :string
    field :description, :string
    field :key, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :description])
    |> validate_required([:key, :value])
    |> unique_constraint(:key)
  end
end
