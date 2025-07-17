defmodule IeeeTamuPortalWeb.AdminSettingsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Repo, Settings.Setting}

  @impl true
  def mount(_params, _session, socket) do
    settings = Repo.all(Setting)

    {:ok, assign(socket, settings: settings), layout: {IeeeTamuPortalWeb.Layouts, :admin}}
  end

  @impl true
  def handle_event("update_setting", %{"setting" => setting_params}, socket) do
    setting = Repo.get!(Setting, setting_params["id"])

    case Setting.changeset(setting, setting_params) |> Repo.update() do
      {:ok, updated_setting} ->
        # Update the settings list with the new value
        updated_settings =
          Enum.map(socket.assigns.settings, fn s ->
            if s.id == updated_setting.id, do: updated_setting, else: s
          end)

        {:noreply,
         socket
         |> assign(settings: updated_settings)
         |> put_flash(:info, "Setting updated successfully")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to update setting: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("create_setting", %{"setting" => setting_params}, socket) do
    case %Setting{} |> Setting.changeset(setting_params) |> Repo.insert() do
      {:ok, new_setting} ->
        updated_settings = [new_setting | socket.assigns.settings]

        {:noreply,
         socket
         |> assign(settings: updated_settings)
         |> put_flash(:info, "Setting created successfully")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create setting: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_setting", %{"id" => id}, socket) do
    setting = Repo.get!(Setting, id)

    case Repo.delete(setting) do
      {:ok, _} ->
        updated_settings = Enum.reject(socket.assigns.settings, &(&1.id == String.to_integer(id)))

        {:noreply,
         socket
         |> assign(settings: updated_settings)
         |> put_flash(:info, "Setting deleted successfully")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to delete setting: #{inspect(changeset.errors)}")}
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

          <.form for={%{}} phx-submit="create_setting">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <.input
                  name="setting[key]"
                  label="Key"
                  placeholder="e.g., registration_year"
                  value=""
                  required
                />
              </div>
              <div>
                <.input
                  name="setting[value]"
                  label="Value"
                  placeholder="e.g., 2025"
                  value=""
                  required
                />
              </div>
              <div>
                <.input
                  name="setting[description]"
                  label="Description"
                  placeholder="Description of this setting"
                  value=""
                />
              </div>
            </div>
            <div class="mt-4">
              <.button type="submit" class="bg-blue-600 hover:bg-blue-700">
                Add Setting
              </.button>
            </div>
          </.form>
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
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Key
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Value
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Description
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
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
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900">
                        {setting.key}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <.form for={%{}} phx-submit="update_setting">
                        <input type="hidden" name="setting[id]" value={setting.id} />
                        <input type="hidden" name="setting[key]" value={setting.key} />
                        <input type="hidden" name="setting[description]" value={setting.description} />
                        <div class="flex items-center space-x-2">
                          <.input
                            name="setting[value]"
                            value={setting.value}
                            class="text-sm"
                            style="border: 1px solid #d1d5db; padding: 0.25rem 0.5rem;"
                          />
                          <.button
                            type="submit"
                            class="text-xs bg-green-600 hover:bg-green-700 px-2 py-1"
                          >
                            Update
                          </.button>
                        </div>
                      </.form>
                    </td>
                    <td class="px-6 py-4">
                      <div class="text-sm text-gray-900 max-w-xs truncate">
                        {setting.description}
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
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
