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
  Fetches a specific setting by key.
  """
  def get_setting(key) do
    Repo.get_by(Setting, key: key)
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
end
