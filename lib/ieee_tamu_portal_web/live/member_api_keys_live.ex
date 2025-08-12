defmodule IeeeTamuPortalWeb.MemberApiKeysLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Api
  alias IeeeTamuPortal.Api.ApiKey

  @impl true
  def mount(_params, _session, %{assigns: %{current_member: member}} = socket) do
    member_keys = list_member_keys(member.id)

    socket =
      socket
      |> assign(:page_title, "API Keys")
      |> assign(:api_keys, member_keys)
      |> assign(:show_form, false)
      |> assign(:form, to_form(Api.change_api_key(%ApiKey{})))
      |> assign(:new_token, nil)
      |> assign(:container_max_class, "max-w-7xl")

    {:ok, socket}
  end

  defp list_member_keys(member_id) do
    import Ecto.Query
    IeeeTamuPortal.Repo.all(
      from k in ApiKey, where: k.member_id == ^member_id, order_by: [desc: k.inserted_at]
    )
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    socket =
      socket
      |> assign(:show_form, false)
      |> assign(:form, to_form(Api.change_api_key(%ApiKey{})))
      |> assign(:new_token, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"api_key" => api_key_params}, socket) do
    changeset =
      %ApiKey{}
      |> Api.change_api_key(api_key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"api_key" => api_key_params}, %{assigns: %{current_member: member}} = socket) do
    # Force context to member and scope to current member
    params =
      api_key_params
      |> Map.put("context", "member")
      |> Map.put("member_id", member.id)

    case Api.create_api_key(params) do
      {:ok, {plain_token, api_key}} ->
        api_keys = [api_key | socket.assigns.api_keys]

        socket =
          socket
          |> assign(:api_keys, api_keys)
          |> assign(:new_token, plain_token)
          |> assign(:form, to_form(Api.change_api_key(%ApiKey{})))
          |> put_flash(:info, "API key created successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, %{assigns: %{current_member: member}} = socket) do
    api_key = Api.get_api_key!(id)

    if api_key.member_id != member.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      case Api.update_api_key(api_key, %{is_active: !api_key.is_active}) do
        {:ok, api_key} ->
          api_keys =
            Enum.map(socket.assigns.api_keys, fn ak ->
              if ak.id == api_key.id, do: api_key, else: ak
            end)

          socket =
            socket
            |> assign(:api_keys, api_keys)
            |> put_flash(:info, "API key updated successfully!")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update API key")}
      end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_member: member}} = socket) do
    api_key = Api.get_api_key!(id)

    if api_key.member_id != member.id do
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    else
      case Api.delete_api_key(api_key) do
        {:ok, api_key} ->
          api_keys = Enum.reject(socket.assigns.api_keys, &(&1.id == api_key.id))

          socket =
            socket
            |> assign(:api_keys, api_keys)
            |> put_flash(:info, "API key deleted successfully!")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete API key")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold leading-6 text-gray-900">API Keys</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage API keys for accessing your data via the API.
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <button
            :if={!@show_form}
            phx-click="show_form"
            type="button"
            class="block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          >
            Create API Key
          </button>
        </div>
      </div>

      <div :if={@new_token} class="mt-6 rounded-md bg-green-50 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <.icon name="hero-check-circle" class="h-5 w-5 text-green-400" />
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-green-800">
              API Key Created Successfully!
            </h3>
            <div class="mt-2 text-sm text-green-700">
              <p class="font-semibold">Your new API key (save this, it won't be shown again):</p>
              <div class="mt-2 font-mono text-xs bg-green-100 p-2 rounded border break-all">
                {@new_token}
              </div>
            </div>
            <div class="mt-4">
              <button phx-click="hide_form" type="button" class="text-sm font-medium text-green-800 underline">
                Dismiss
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={@show_form and !@new_token} class="mt-6">
        <div class="rounded-lg border border-gray-200 bg-white p-6">
          <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Create New API Key</h3>

          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Name" placeholder="e.g., My Script" />

            <div class="flex items-center gap-4">
              <.button phx-disable-with="Creating...">Create API Key</.button>
              <button phx-click="hide_form" type="button" class="text-sm font-medium text-gray-500 hover:text-gray-700">
                Cancel
              </button>
            </div>
          </.simple_form>
        </div>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">
                      Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Token Prefix
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Last Used
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Status
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Created
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr :for={api_key <- @api_keys}>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      {api_key.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono">
                      {api_key.prefix}...
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <span :if={api_key.last_used_at}>
                        {Calendar.strftime(api_key.last_used_at, "%b %d, %Y at %I:%M %p")}
                      </span>
                      <span :if={!api_key.last_used_at} class="text-gray-400">Never used</span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <span :if={api_key.is_active} class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                        Active
                      </span>
                      <span :if={!api_key.is_active} class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
                        Inactive
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {Calendar.strftime(api_key.inserted_at, "%b %d, %Y")}
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <button phx-click="toggle_active" phx-value-id={api_key.id} class="text-indigo-600 hover:text-indigo-900 mr-4">
                        {if api_key.is_active, do: "Deactivate", else: "Activate"}
                      </button>
                      <button phx-click="delete" phx-value-id={api_key.id} class="text-red-600 hover:text-red-900">
                        Delete
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>

              <div :if={@api_keys == []} class="text-center py-12 bg-white">
                <.icon name="hero-key" class="mx-auto h-12 w-12 text-gray-400" />
                <h3 class="mt-2 text-sm font-semibold text-gray-900">No API keys</h3>
                <p class="mt-1 text-sm text-gray-500">Get started by creating your first API key.</p>
                <div class="mt-6">
                  <button phx-click="show_form" type="button" class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">
                    <.icon name="hero-plus" class="-ml-0.5 mr-1.5 h-5 w-5" /> Create API Key
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
