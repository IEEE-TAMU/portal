defmodule IeeeTamuPortal.SettingsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `IeeeTamuPortal.Settings` context.
  """

  import Ecto.Query

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

  def current_event_uid_setting_fixture(event_uid) do
    delete_setting("current_event_uid")

    {:ok, setting} =
      Settings.create_setting(%{
        key: "current_event_uid",
        value: event_uid,
        description: "Current active event uid"
      })

    setting
  end

  defp delete_setting(key) do
    IeeeTamuPortal.Repo.delete_all(
      from(s in IeeeTamuPortal.Settings.Setting, where: s.key == ^key)
    )
  end
end
