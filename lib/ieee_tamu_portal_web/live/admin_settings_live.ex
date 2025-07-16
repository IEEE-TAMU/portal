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
end
