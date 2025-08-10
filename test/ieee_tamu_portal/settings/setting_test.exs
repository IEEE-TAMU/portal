defmodule IeeeTamuPortal.Settings.SettingTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Settings.Setting

  describe "create_changeset/2" do
    test "changeset with valid attributes" do
      attrs = %{
        key: "test_key",
        value: "test_value",
        description: "test description"
      }

      changeset = Setting.create_changeset(%Setting{}, attrs)
      assert changeset.valid?
      assert changeset.changes.key == "test_key"
      assert changeset.changes.value == "test_value"
      assert changeset.changes.description == "test description"
    end

    test "changeset without description is valid" do
      attrs = %{key: "test_key", value: "test_value"}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      assert changeset.valid?
    end

    test "changeset requires key" do
      attrs = %{value: "test_value"}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).key
    end

    test "changeset requires value" do
      attrs = %{key: "test_key"}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).value
    end

    test "changeset validates key length minimum" do
      attrs = %{key: "", value: "test_value"}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).key
    end

    test "changeset validates key length maximum" do
      long_key = String.duplicate("a", 256)
      attrs = %{key: long_key, value: "test_value"}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).key
    end

    test "changeset validates value length minimum" do
      attrs = %{key: "test_key", value: ""}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).value
    end

    test "changeset validates value length maximum" do
      long_value = String.duplicate("a", 1001)
      attrs = %{key: "test_key", value: long_value}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).value
    end

    test "changeset validates description length maximum" do
      long_description = String.duplicate("a", 1001)
      attrs = %{key: "test_key", value: "test_value", description: long_description}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).description
    end

    test "changeset accepts maximum valid lengths" do
      max_key = String.duplicate("a", 255)
      max_value = String.duplicate("b", 1000)
      max_description = String.duplicate("c", 1000)

      attrs = %{key: max_key, value: max_value, description: max_description}
      changeset = Setting.create_changeset(%Setting{}, attrs)
      assert changeset.valid?
    end
  end

  describe "update_changeset/2" do
    test "changeset with valid value" do
      setting = %Setting{key: "existing_key", value: "old_value"}
      attrs = %{value: "new_value"}

      changeset = Setting.update_changeset(setting, attrs)
      assert changeset.valid?
      assert changeset.changes.value == "new_value"
    end

    test "changeset requires value" do
      setting = %Setting{key: "existing_key", value: "old_value"}
      attrs = %{value: ""}

      changeset = Setting.update_changeset(setting, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).value
    end

    test "changeset validates value length maximum" do
      setting = %Setting{key: "existing_key", value: "old_value"}
      long_value = String.duplicate("a", 1001)
      attrs = %{value: long_value}

      changeset = Setting.update_changeset(setting, attrs)
      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).value
    end

    test "changeset ignores key field" do
      setting = %Setting{key: "existing_key", value: "old_value"}
      attrs = %{key: "new_key", value: "new_value"}

      changeset = Setting.update_changeset(setting, attrs)
      assert changeset.valid?
      assert changeset.changes.value == "new_value"
      refute Map.has_key?(changeset.changes, :key)
    end

    test "changeset ignores description field" do
      setting = %Setting{key: "existing_key", value: "old_value", description: "old desc"}
      attrs = %{description: "new description", value: "new_value"}

      changeset = Setting.update_changeset(setting, attrs)
      assert changeset.valid?
      assert changeset.changes.value == "new_value"
      refute Map.has_key?(changeset.changes, :description)
    end

    test "changeset accepts maximum valid value length" do
      setting = %Setting{key: "existing_key", value: "old_value"}
      max_value = String.duplicate("a", 1000)
      attrs = %{value: max_value}

      changeset = Setting.update_changeset(setting, attrs)
      assert changeset.valid?
    end
  end
end
