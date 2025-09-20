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

  require Logger

  @default_year 2025
  @default_current_event "NONE"

  # Gets a setting by its key.
  # Returns the setting struct if found, nil otherwise.
  defp get_setting(key) do
    Repo.get_by(Setting, key: key)
  end

  # Expose a public getter by key when needed by UIs.
  def get_setting_by_key(key), do: get_setting(key)

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
    |> Setting.create_changeset(attrs)
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
    |> Setting.update_changeset(attrs)
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

  @doc """
  Gets the current registration year as an integer.

  This is a convenience function that fetches the "registration_year" setting
  and converts its value to an integer. This setting is used throughout the
  application to determine which academic year registrations apply to.

  Raises an error if the "registration_year" setting is not found, as this
  is considered a critical application setting.

  ## Examples

      iex> get_registration_year!()
      2024

  ## Raises

    * `RuntimeError` - when the "registration_year" setting is not found
  """
  def get_registration_year! do
    case get_setting("registration_year") do
      nil ->
        Logger.error("Membership year setting not found - defaulting to #{@default_year}")
        @default_year

      setting ->
        try do
          setting.value |> String.to_integer()
        rescue
          ArgumentError ->
            Logger.error(
              "Invalid registration year format in setting: #{setting.value} - defaulting to #{@default_year}"
            )

            @default_year
        end
    end
  end

  @doc """
  Gets the current event name as a string used for event check-ins.

  This reads the "current_event" setting. If not present, returns a sensible
  default value.

  ## Examples

      iex> get_current_event!()
      "general_meeting"
  """
  def get_current_event! do
    case get_setting("current_event") do
      nil -> @default_current_event
      setting -> setting.value
    end
  end

  def default_current_event, do: @default_current_event

  @doc """
  Sets the current event name (string) used for check-ins.

  Creates or updates the `current_event` setting. Returns `{:ok, %Setting{}}` or `{:error, changeset}`.
  """
  def set_current_event(event_name) when is_binary(event_name) do
    upsert_setting("current_event", event_name)
  end

  @doc """
  Stops the current event by resetting it to the default value ("NONE").

  Returns `{:ok, %Setting{}}` or `{:error, changeset}`.
  """
  def stop_current_event do
    upsert_setting("current_event", @default_current_event)
  end

  # Creates or updates a setting by key with the provided value.
  defp upsert_setting(key, value) do
    case get_setting(key) do
      nil ->
        create_setting(%{key: key, value: value})

      %Setting{} = setting ->
        update_setting(setting, %{value: value})
    end
  end

  @doc """
  Returns a changeset for creating a new setting.

  ## Examples

      iex> change_setting(%Setting{})
      %Ecto.Changeset{data: %Setting{}}
  """
  def change_setting(%Setting{} = setting, attrs \\ %{}) do
    Setting.create_changeset(setting, attrs)
  end

  @doc """
  Returns a changeset for updating an existing setting.

  ## Examples

      iex> change_setting_update(setting)
      %Ecto.Changeset{data: %Setting{}}
  """
  def change_setting_update(%Setting{} = setting, attrs \\ %{}) do
    Setting.update_changeset(setting, attrs)
  end
end
