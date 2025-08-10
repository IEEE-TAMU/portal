defmodule IeeeTamuPortal.Settings.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :value, :string
    field :description, :string
    field :key, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating a new setting.
  """
  def create_changeset(setting, attrs \\ %{}) do
    setting
    |> cast(attrs, [:key, :value, :description])
    |> validate_required([:key, :value])
    |> validate_length(:key, min: 1, max: 255)
    |> validate_length(:value, min: 1, max: 1000)
    |> validate_length(:description, max: 1000)
    |> unique_constraint(:key)
  end

  @doc """
  A changeset for updating an existing setting.
  """
  def update_changeset(setting, attrs \\ %{}) do
    setting
    |> cast(attrs, [:value])
    |> validate_required([:value])
    |> validate_length(:value, min: 1, max: 1000)
  end
end
