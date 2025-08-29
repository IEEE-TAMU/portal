defmodule IeeeTamuPortal.SettingsTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortal.Settings.Setting

  import IeeeTamuPortal.SettingsFixtures

  setup do
    # Clean up any seeded settings for test isolation
    IeeeTamuPortal.Repo.delete_all(Setting)
    :ok
  end

  describe "all_settings/0" do
    test "returns empty list when no settings exist" do
      assert Settings.all_settings() == []
    end

    test "returns all settings" do
      setting1 = setting_fixture(%{key: "setting1", value: "value1"})
      setting2 = setting_fixture(%{key: "setting2", value: "value2"})

      settings = Settings.all_settings()
      assert length(settings) == 2
      assert Enum.any?(settings, &(&1.id == setting1.id))
      assert Enum.any?(settings, &(&1.id == setting2.id))
    end
  end

  describe "get_setting!/1" do
    test "returns the setting with given id" do
      setting = setting_fixture()
      assert Settings.get_setting!(setting.id).id == setting.id
    end

    test "raises when setting does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Settings.get_setting!(999)
      end
    end
  end

  describe "create_setting/1" do
    test "creates a setting with valid data" do
      valid_attrs = %{
        key: "test_key",
        value: "test_value",
        description: "test description"
      }

      assert {:ok, %Setting{} = setting} = Settings.create_setting(valid_attrs)
      assert setting.key == "test_key"
      assert setting.value == "test_value"
      assert setting.description == "test description"
    end

    test "creates a setting without description" do
      valid_attrs = %{
        key: "test_key",
        value: "test_value"
      }

      assert {:ok, %Setting{} = setting} = Settings.create_setting(valid_attrs)
      assert setting.key == "test_key"
      assert setting.value == "test_value"
      assert setting.description == nil
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(%{})
    end

    test "returns error changeset when key is missing" do
      invalid_attrs = %{value: "test_value"}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when value is missing" do
      invalid_attrs = %{key: "test_key"}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when key is empty" do
      invalid_attrs = %{key: "", value: "test_value"}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when value is empty" do
      invalid_attrs = %{key: "test_key", value: ""}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when key is too long" do
      long_key = String.duplicate("a", 256)
      invalid_attrs = %{key: long_key, value: "test_value"}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when value is too long" do
      long_value = String.duplicate("a", 1001)
      invalid_attrs = %{key: "test_key", value: long_value}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when description is too long" do
      long_description = String.duplicate("a", 1001)
      invalid_attrs = %{key: "test_key", value: "test_value", description: long_description}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(invalid_attrs)
    end

    test "returns error changeset when key already exists" do
      setting_fixture(%{key: "duplicate_key"})

      duplicate_attrs = %{key: "duplicate_key", value: "different_value"}
      assert {:error, %Ecto.Changeset{}} = Settings.create_setting(duplicate_attrs)
    end
  end

  describe "update_setting/2" do
    test "updates the setting with valid data" do
      setting = setting_fixture()
      update_attrs = %{value: "updated_value"}

      assert {:ok, %Setting{} = updated_setting} = Settings.update_setting(setting, update_attrs)
      assert updated_setting.value == "updated_value"
      assert updated_setting.key == setting.key
      assert updated_setting.description == setting.description
    end

    test "returns error changeset with invalid data" do
      setting = setting_fixture()
      invalid_attrs = %{value: ""}

      assert {:error, %Ecto.Changeset{}} = Settings.update_setting(setting, invalid_attrs)
      assert setting == Settings.get_setting!(setting.id)
    end

    test "returns error changeset when value is too long" do
      setting = setting_fixture()
      long_value = String.duplicate("a", 1001)
      invalid_attrs = %{value: long_value}

      assert {:error, %Ecto.Changeset{}} = Settings.update_setting(setting, invalid_attrs)
    end

    test "ignores key and description in update" do
      setting = setting_fixture(%{key: "original_key", description: "original_description"})

      update_attrs = %{
        key: "new_key",
        value: "new_value",
        description: "new_description"
      }

      assert {:ok, %Setting{} = updated_setting} = Settings.update_setting(setting, update_attrs)
      assert updated_setting.value == "new_value"
      assert updated_setting.key == "original_key"
      assert updated_setting.description == "original_description"
    end
  end

  describe "delete_setting/1" do
    test "deletes the setting" do
      setting = setting_fixture()
      assert {:ok, %Setting{}} = Settings.delete_setting(setting)
      assert_raise Ecto.NoResultsError, fn -> Settings.get_setting!(setting.id) end
    end
  end

  describe "get_registration_year!/0" do
    test "returns the registration year as an integer when setting exists" do
      registration_year_setting_fixture("2024")
      assert Settings.get_registration_year!() == 2024
    end

    test "returns default year when registration_year setting does not exist" do
      # Ensure no registration_year setting exists (already handled by setup)
      assert Settings.get_registration_year!() == 2025
    end

    test "returns default year when registration_year value is invalid" do
      registration_year_setting_fixture("invalid_year")
      assert Settings.get_registration_year!() == 2025
    end

    test "handles different valid year formats" do
      registration_year_setting_fixture("2023")
      assert Settings.get_registration_year!() == 2023
    end

    test "logs error when setting not found" do
      import ExUnit.CaptureLog

      # Ensure no registration_year setting exists (already handled by setup)
      log =
        capture_log(fn ->
          assert Settings.get_registration_year!() == 2025
        end)

      assert log =~ "Membership year setting not found - defaulting to 2025"
    end

    test "logs error when value format is invalid" do
      import ExUnit.CaptureLog

      registration_year_setting_fixture("not_a_number")

      log =
        capture_log(fn ->
          assert Settings.get_registration_year!() == 2025
        end)

      assert log =~
               "Invalid registration year format in setting: not_a_number - defaulting to 2025"
    end
  end

  describe "change_setting/2" do
    test "returns a setting changeset for create" do
      changeset = Settings.change_setting(%Setting{})
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == %Setting{}
    end

    test "returns a setting changeset with given attributes" do
      attrs = %{key: "test_key", value: "test_value"}
      changeset = Settings.change_setting(%Setting{}, attrs)
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.key == "test_key"
      assert changeset.changes.value == "test_value"
    end
  end

  describe "change_setting_update/2" do
    test "returns an update changeset for existing setting" do
      setting = setting_fixture()
      changeset = Settings.change_setting_update(setting)
      assert %Ecto.Changeset{} = changeset
      assert changeset.data == setting
    end

    test "returns an update changeset with given attributes" do
      setting = setting_fixture()
      attrs = %{value: "updated_value"}
      changeset = Settings.change_setting_update(setting, attrs)
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.value == "updated_value"
    end

    test "update changeset ignores key changes" do
      setting = setting_fixture()
      attrs = %{key: "new_key", value: "updated_value"}
      changeset = Settings.change_setting_update(setting, attrs)
      assert %Ecto.Changeset{} = changeset
      assert changeset.changes.value == "updated_value"
      refute Map.has_key?(changeset.changes, :key)
    end
  end

  describe "get_current_event!/0" do
    test "returns the current event name when setting exists" do
      current_event_setting_fixture("first_meeting")
      assert Settings.get_current_event!() == "first_meeting"
    end

    test "returns default event when current_event setting does not exist" do
      # setup removed all settings
      assert is_binary(Settings.get_current_event!())
    end
  end
end
