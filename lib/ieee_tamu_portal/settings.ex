defmodule IeeeTamuPortal.Settings do
  @moduledoc """
  The Settings context.

  This module provides functions for managing global application settings that are
  persisted to the database. Settings are key-value pairs that control various
  aspects of the IEEE TAMU Portal application behavior.

  Settings should be initialized through database migrations and can be managed
  through the admin interface.

  ## Examples

      iex> Settings.all_settings()
      [%Setting{key: "registration_year", value: "2024"}, ...]

      iex> Settings.get_registration_year!()
      2024
  """
  use Ecto.Schema

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Settings.Setting

  defp get_setting(key) do
    Repo.get_by(Setting, key: key)
  end

  @doc """
  Fetches all settings from the database.

  Returns a list of all setting structs ordered by their insertion time.

  ## Examples

      iex> all_settings()
      [%Setting{key: "registration_year", value: "2024"}, ...]
  """
  def all_settings do
    Repo.all(Setting)
  end

  @doc """
  Gets a setting by its ID.

  Raises `Ecto.NoResultsError` if the setting does not exist.

  ## Examples

      iex> get_setting!(123)
      %Setting{id: 123, key: "registration_year", value: "2024"}

      iex> get_setting!(999)
      ** (Ecto.NoResultsError)
  """
  def get_setting!(id) do
    Repo.get!(Setting, id)
  end

  @doc """
  Creates a new setting with the given attributes.

  ## Parameters

    * `attrs` - A map of attributes for the new setting, typically including
      `:key`, `:value`, and optionally `:description`

  ## Examples

      iex> create_setting(%{key: "feature_flag", value: "enabled", description: "Feature toggle"})
      {:ok, %Setting{}}

      iex> create_setting(%{key: ""})
      {:error, %Ecto.Changeset{}}
  """
  def create_setting(attrs) do
    %Setting{}
    |> Setting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a setting with the given attributes.

  ## Parameters

    * `setting` - The setting struct to update
    * `attrs` - A map of attributes to update

  ## Examples

      iex> update_setting(setting, %{value: "new_value"})
      {:ok, %Setting{}}

      iex> update_setting(setting, %{key: ""})
      {:error, %Ecto.Changeset{}}
  """
  def update_setting(setting, attrs) do
    setting
    |> Setting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a setting.

  ## Parameters

    * `setting` - The setting struct to delete

  ## Examples

      iex> delete_setting(setting)
      {:ok, %Setting{}}

      iex> delete_setting(invalid_setting)
      {:error, %Ecto.Changeset{}}
  """
  def delete_setting(setting) do
    Repo.delete(setting)
  end

  def get_registration_year! do
    case get_setting("registration_year") do
      nil -> raise "Membership year setting not found"
      setting -> setting.value |> String.to_integer()
    end
  end
end
