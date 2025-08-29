defmodule IeeeTamuPortal.SettingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `IeeeTamuPortal.Settings` context.
  """

  alias IeeeTamuPortal.Settings

  def valid_setting_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      key: "test_setting_#{System.unique_integer()}",
      value: "test_value",
      description: "A test setting"
    })
  end

  def setting_fixture(attrs \\ %{}) do
    {:ok, setting} =
      attrs
      |> valid_setting_attributes()
      |> Settings.create_setting()

    setting
  end

  def registration_year_setting_fixture(year \\ "2024") do
    # First try to delete any existing registration_year setting
    case IeeeTamuPortal.Repo.get_by(IeeeTamuPortal.Settings.Setting, key: "registration_year") do
      nil -> :ok
      existing_setting -> IeeeTamuPortal.Repo.delete!(existing_setting)
    end

    {:ok, setting} =
      Settings.create_setting(%{
        key: "registration_year",
        value: year,
        description: "Current year for member registrations"
      })

    setting
  end

  def current_event_setting_fixture(event_name \\ "general_meeting") do
    case IeeeTamuPortal.Repo.get_by(IeeeTamuPortal.Settings.Setting, key: "current_event") do
      nil -> :ok
      existing_setting -> IeeeTamuPortal.Repo.delete!(existing_setting)
    end

    {:ok, setting} =
      Settings.create_setting(%{
        key: "current_event",
        value: event_name,
        description: "Current event for member check-ins"
      })

    setting
  end
end
