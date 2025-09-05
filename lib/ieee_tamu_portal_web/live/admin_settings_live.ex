defmodule IeeeTamuPortalWeb.AdminSettingsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.all_settings()
    create_changeset = Settings.change_setting(%Settings.Setting{})

    {:ok,
     assign(socket,
       settings: settings,
       create_form: to_form(create_changeset),
       update_forms: build_update_forms(settings)
     )}
  end

  defp build_update_forms(settings) do
    settings
    |> Enum.map(fn setting ->
      {setting.id, to_form(Settings.change_setting_update(setting))}
    end)
    |> Map.new()
  end

  @impl true
  def handle_event("validate_create", %{"setting" => setting_params}, socket) do
    create_form =
      %Settings.Setting{}
      |> Settings.change_setting(setting_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, create_form: create_form)}
  end

  @impl true
  def handle_event("create_setting", %{"setting" => setting_params}, socket) do
    case Settings.create_setting(setting_params) do
      {:ok, new_setting} ->
        updated_settings = [new_setting | socket.assigns.settings]
        updated_forms = build_update_forms(updated_settings)
        create_changeset = Settings.change_setting(%Settings.Setting{})

        {:noreply,
         socket
         |> assign(
           settings: updated_settings,
           update_forms: updated_forms,
           create_form: to_form(create_changeset)
         )
         |> put_flash(:info, "Setting created successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(create_form: to_form(changeset))
         |> put_flash(:error, "Failed to create setting")}
    end
  end

  @impl true
  def handle_event("validate_update", %{"setting" => setting_params}, socket) do
    setting = Settings.get_setting!(setting_params["id"])

    update_form =
      setting
      |> Settings.change_setting_update(setting_params)
      |> Map.put(:action, :validate)
      |> to_form()

    updated_forms = Map.put(socket.assigns.update_forms, setting.id, update_form)

    {:noreply, assign(socket, update_forms: updated_forms)}
  end

  @impl true
  def handle_event("update_setting", %{"setting" => setting_params}, socket) do
    setting = Settings.get_setting!(setting_params["id"])

    case Settings.update_setting(setting, setting_params) do
      {:ok, updated_setting} ->
        # Update the settings list with the new value
        updated_settings =
          Enum.map(socket.assigns.settings, fn s ->
            if s.id == updated_setting.id, do: updated_setting, else: s
          end)

        updated_forms = build_update_forms(updated_settings)

        {:noreply,
         socket
         |> assign(settings: updated_settings, update_forms: updated_forms)
         |> put_flash(:info, "Setting updated successfully")}

      {:error, changeset} ->
        updated_forms = Map.put(socket.assigns.update_forms, setting.id, to_form(changeset))

        {:noreply,
         socket
         |> assign(update_forms: updated_forms)
         |> put_flash(:error, "Failed to update setting")}
    end
  end

  @impl true
  def handle_event("delete_setting", %{"id" => id}, socket) do
    setting = Settings.get_setting!(id)

    case Settings.delete_setting(setting) do
      {:ok, _} ->
        setting_id = String.to_integer(id)
        updated_settings = Enum.reject(socket.assigns.settings, &(&1.id == setting_id))
        updated_forms = build_update_forms(updated_settings)

        {:noreply,
         socket
         |> assign(settings: updated_settings, update_forms: updated_forms)
         |> put_flash(:info, "Setting deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete setting")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <.header>
        Global Settings
        <:subtitle>Manage application-wide settings</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Add New Setting Form -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Add New Setting</h3>

          <.simple_form
            for={@create_form}
            id="create_setting_form"
            phx-change="validate_create"
            phx-submit="create_setting"
          >
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <.input
                  field={@create_form[:key]}
                  id="create_setting_key"
                  label="Key"
                  placeholder="e.g., registration_year"
                  required
                />
              </div>
              <div>
                <.input
                  field={@create_form[:value]}
                  id="create_setting_value"
                  label="Value"
                  placeholder="e.g., 2025"
                  required
                />
              </div>
              <div>
                <.input
                  field={@create_form[:description]}
                  id="create_setting_description"
                  label="Description"
                  placeholder="Description of this setting"
                />
              </div>
            </div>
            <:actions>
              <.button type="submit" class="bg-blue-600 hover:bg-blue-700">
                Add Setting
              </.button>
            </:actions>
          </.simple_form>
        </div>
        
    <!-- Existing Settings -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Current Settings</h3>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-2 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Key
                  </th>
                  <th class="px-2 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Value
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden lg:table-cell">
                    Description
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden lg:table-cell">
                    Last Updated
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for setting <- @settings do %>
                  <tr>
                    <td class="px-2 sm:px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900 max-w-[14ch] truncate sm:max-w-none">
                        {setting.key}
                      </div>
                    </td>
                    <td class="px-2 sm:px-6 py-4 align-middle w-full">
                      <.form
                        for={Map.get(@update_forms, setting.id)}
                        id={"update_setting_form_#{setting.id}"}
                        phx-change="validate_update"
                        phx-submit="update_setting"
                        class="m-0"
                      >
                        <input type="hidden" name="setting[id]" value={setting.id} />
                        <div class="flex items-center gap-1.5 sm:gap-2 w-full">
                          <.input
                            field={Map.get(@update_forms, setting.id)[:value]}
                            id={"setting_value_#{setting.id}"}
                            class="text-sm m-0 flex-1 min-w-[12rem] sm:min-w-[16rem]"
                            style="border: 1px solid #d1d5db; padding: 0.25rem 0.5rem;"
                          />
                          <.button
                            type="submit"
                            class="text-xs bg-green-600 hover:bg-green-700 px-2 py-1 flex-none"
                          >
                            Update
                          </.button>
                        </div>
                      </.form>
                    </td>
                    <td class="px-6 py-4 hidden lg:table-cell">
                      <div class="text-sm text-gray-900 max-w-xs truncate">
                        {setting.description}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 hidden lg:table-cell">
                      {Calendar.strftime(setting.updated_at, "%b %d, %Y at %I:%M %p")}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <.button
                        phx-click="delete_setting"
                        phx-value-id={setting.id}
                        data-confirm="Are you sure you want to delete this setting?"
                        class="text-red-600 hover:text-red-900 bg-red-100 hover:bg-red-200 px-2 py-1 text-xs"
                      >
                        Delete
                      </.button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%= if Enum.empty?(@settings) do %>
              <div class="text-center py-12">
                <div class="text-gray-500">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No settings</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Get started by creating a new setting above.
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
