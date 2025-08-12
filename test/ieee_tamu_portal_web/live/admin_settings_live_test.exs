defmodule IeeeTamuPortalWeb.AdminSettingsLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortal.Settings.Setting

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.SettingsFixtures
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]

  setup do
    # Clean up any seeded settings for test isolation
    IeeeTamuPortal.Repo.delete_all(Setting)
    :ok
  end

  describe "Admin Settings page" do
    test "renders admin settings page with proper authentication", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      assert html =~ "Global Settings"
      assert html =~ "Add New Setting"
      assert html =~ "Current Settings"
    end

    test "redirects if admin is not authenticated", %{conn: conn} do
      # The admin route should return 401 Unauthorized when not authenticated
      conn = get(conn, ~p"/admin/settings")
      assert conn.status == 401
    end

    test "shows empty state when no settings exist", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      assert html =~ "No settings"
      assert html =~ "Get started by creating a new setting above"
    end

    test "displays existing settings in table", %{conn: conn} do
      setting1 =
        setting_fixture(%{
          key: "test_key_1",
          value: "test_value_1",
          description: "Test setting 1"
        })

      setting2 =
        setting_fixture(%{
          key: "test_key_2",
          value: "test_value_2",
          description: "Test setting 2"
        })

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      assert html =~ setting1.key
      assert html =~ setting1.value
      assert html =~ setting1.description
      assert html =~ setting2.key
      assert html =~ setting2.value
      assert html =~ setting2.description
    end
  end

  describe "create setting form" do
    test "validates create form on change", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      result =
        lv
        |> element("#create_setting_form")
        |> render_change(%{
          "setting" => %{
            "key" => "",
            "value" => "",
            "description" => "test description"
          }
        })

      assert result =~ "can&#39;t be blank"
    end

    test "creates a new setting with valid data", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "new_test_key",
          "value" => "new_test_value",
          "description" => "A new test setting"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Setting created successfully"
      assert result =~ "new_test_key"
      assert result =~ "new_test_value"
      assert result =~ "A new test setting"

      # Verify setting was actually created in database
      setting = Settings.all_settings() |> List.first()
      assert setting.key == "new_test_key"
      assert setting.value == "new_test_value"
      assert setting.description == "A new test setting"
    end

    test "shows error when creating setting with invalid data", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "",
          "value" => "test_value",
          "description" => "test description"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Failed to create setting"
      assert result =~ "can&#39;t be blank"
    end

    test "shows error when creating setting with duplicate key", %{conn: conn} do
      setting_fixture(%{key: "duplicate_key", value: "original_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "duplicate_key",
          "value" => "new_value",
          "description" => "duplicate setting"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Failed to create setting"
      assert result =~ "has already been taken"
    end

    test "clears form after successful creation", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "clear_test_key",
          "value" => "clear_test_value",
          "description" => "test clearing"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Setting created successfully"

      # Check that form inputs are cleared
      create_form = element(lv, "#create_setting_form")
      form_html = render(create_form)
      refute form_html =~ "clear_test_key"
      refute form_html =~ "clear_test_value"
    end
  end

  describe "update setting form" do
    test "validates update form on change", %{conn: conn} do
      setting = setting_fixture(%{key: "update_test", value: "original_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      result =
        lv
        |> element("#update_setting_form_#{setting.id}")
        |> render_change(%{
          "setting" => %{
            "id" => to_string(setting.id),
            "value" => ""
          }
        })

      assert result =~ "can&#39;t be blank"
    end

    test "updates setting with valid data", %{conn: conn} do
      setting =
        setting_fixture(%{
          key: "update_test",
          value: "original_value",
          description: "Original description"
        })

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => "updated_value"
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting.id}", form_data)
        |> render_submit()

      assert result =~ "Setting updated successfully"
      assert result =~ "updated_value"

      # Verify setting was actually updated in database
      updated_setting = Settings.get_setting!(setting.id)
      assert updated_setting.value == "updated_value"
      # Key should not change
      assert updated_setting.key == setting.key
      # Description should not change
      assert updated_setting.description == setting.description
    end

    test "shows error when updating setting with invalid data", %{conn: conn} do
      setting = setting_fixture(%{key: "update_test", value: "original_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => ""
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting.id}", form_data)
        |> render_submit()

      assert result =~ "Failed to update setting"
      assert result =~ "can&#39;t be blank"

      # Verify setting was not changed in database
      unchanged_setting = Settings.get_setting!(setting.id)
      assert unchanged_setting.value == "original_value"
    end

    test "updates registration_year setting specifically", %{conn: conn} do
      registration_year_setting_fixture("2024")

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      setting = Settings.all_settings() |> Enum.find(&(&1.key == "registration_year"))

      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => "2026"
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting.id}", form_data)
        |> render_submit()

      assert result =~ "Setting updated successfully"
      assert result =~ "2026"

      # Verify the registration year function returns the new value
      assert Settings.get_registration_year!() == 2026
    end
  end

  describe "delete setting" do
    test "deletes setting with confirmation", %{conn: conn} do
      setting = setting_fixture(%{key: "delete_test", value: "delete_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      # The delete button has a data-confirm attribute, but in tests we can trigger it directly
      result =
        lv
        |> element("button[phx-click='delete_setting'][phx-value-id='#{setting.id}']")
        |> render_click()

      assert result =~ "Setting deleted successfully"
      refute result =~ "delete_test"
      refute result =~ "delete_value"

      # Verify setting was actually deleted from database
      assert_raise Ecto.NoResultsError, fn ->
        Settings.get_setting!(setting.id)
      end
    end

    test "shows empty state after deleting all settings", %{conn: conn} do
      setting = setting_fixture(%{key: "last_setting", value: "last_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      result =
        lv
        |> element("button[phx-click='delete_setting'][phx-value-id='#{setting.id}']")
        |> render_click()

      assert result =~ "Setting deleted successfully"
      assert result =~ "No settings"
      assert result =~ "Get started by creating a new setting above"
    end

    test "updates settings list after deletion", %{conn: conn} do
      setting1 = setting_fixture(%{key: "keep_setting", value: "keep_value"})
      setting2 = setting_fixture(%{key: "delete_setting", value: "delete_value"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      result =
        lv
        |> element("button[phx-click='delete_setting'][phx-value-id='#{setting2.id}']")
        |> render_click()

      assert result =~ "Setting deleted successfully"
      assert result =~ "keep_setting"
      assert result =~ "keep_value"
      refute result =~ "delete_value"

      # Verify only the correct setting was deleted
      assert Settings.get_setting!(setting1.id)

      assert_raise Ecto.NoResultsError, fn ->
        Settings.get_setting!(setting2.id)
      end
    end
  end

  describe "flash messages" do
    test "shows success flash for create operation", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "flash_test_key",
          "value" => "flash_test_value",
          "description" => "flash test"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Setting created successfully"
    end

    test "shows error flash for create operation", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "key" => "",
          "value" => "test_value"
        }
      }

      result =
        lv
        |> form("#create_setting_form", form_data)
        |> render_submit()

      assert result =~ "Failed to create setting"
    end

    test "shows success flash for update operation", %{conn: conn} do
      setting = setting_fixture(%{key: "flash_update_test", value: "original"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => "updated"
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting.id}", form_data)
        |> render_submit()

      assert result =~ "Setting updated successfully"
    end

    test "shows error flash for update operation", %{conn: conn} do
      setting = setting_fixture(%{key: "flash_update_error_test", value: "original"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => ""
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting.id}", form_data)
        |> render_submit()

      assert result =~ "Failed to update setting"
    end

    test "shows success flash for delete operation", %{conn: conn} do
      setting = setting_fixture(%{key: "flash_delete_test", value: "delete_me"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      result =
        lv
        |> element("button[phx-click='delete_setting'][phx-value-id='#{setting.id}']")
        |> render_click()

      assert result =~ "Setting deleted successfully"
    end
  end

  describe "form state management" do
    test "maintains separate form states for multiple settings", %{conn: conn} do
      setting1 = setting_fixture(%{key: "form_test_1", value: "value_1"})
      setting2 = setting_fixture(%{key: "form_test_2", value: "value_2"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      # Change first form to have validation error
      lv
      |> element("#update_setting_form_#{setting1.id}")
      |> render_change(%{
        "setting" => %{
          "id" => to_string(setting1.id),
          "value" => ""
        }
      })

      # Second form should still be valid and updateable
      form_data = %{
        "setting" => %{
          "id" => to_string(setting2.id),
          "value" => "updated_value_2"
        }
      }

      result =
        lv
        |> form("#update_setting_form_#{setting2.id}", form_data)
        |> render_submit()

      assert result =~ "Setting updated successfully"

      # Verify second setting was updated while first remained unchanged
      updated_setting2 = Settings.get_setting!(setting2.id)
      unchanged_setting1 = Settings.get_setting!(setting1.id)

      assert updated_setting2.value == "updated_value_2"
      assert unchanged_setting1.value == "value_1"
    end

    test "form states are rebuilt after successful operations", %{conn: conn} do
      setting = setting_fixture(%{key: "rebuild_test", value: "original"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/settings")

      # Update the setting
      form_data = %{
        "setting" => %{
          "id" => to_string(setting.id),
          "value" => "updated"
        }
      }

      lv
      |> form("#update_setting_form_#{setting.id}", form_data)
      |> render_submit()

      # Form should reflect the updated value
      form_element = element(lv, "#update_setting_form_#{setting.id}")
      form_html = render(form_element)
      assert form_html =~ "updated"
    end
  end
end
