defmodule IeeeTamuPortalWeb.AdminOidcClientsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.OIDC.Client
  alias IeeeTamuPortal.OIDC.Clients

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "IEEE Admin - OIDC Clients")
      |> assign(:clients, Clients.list_clients())
      |> assign(:show_form, false)
      |> assign(:editing_client, nil)
      |> assign(:form, new_form())
      |> assign(:new_secret, nil)
      |> assign(:new_client_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       editing_client: nil,
       form: new_form(),
       new_secret: nil,
       new_client_id: nil
     )}
  end

  def handle_event("hide_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: false,
       editing_client: nil,
       form: new_form(),
       new_secret: nil,
       new_client_id: nil
     )}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    client = Clients.get_client!(id)

    {:noreply,
     assign(socket,
       show_form: true,
       editing_client: client,
       form: to_form(Client.change_client(client)),
       new_secret: nil,
       new_client_id: nil
     )}
  end

  def handle_event("validate", %{"client" => params}, socket) do
    changeset =
      case socket.assigns.editing_client do
        nil -> Client.changeset(%Client{}, params)
        client -> Client.update_changeset(client, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"client" => params}, socket) do
    case socket.assigns.editing_client do
      nil -> create_client(socket, params)
      client -> update_client(socket, client, params)
    end
  end

  def handle_event("dismiss_secret", _params, socket) do
    {:noreply, assign(socket, new_secret: nil, new_client_id: nil)}
  end

  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    client = Clients.get_client!(id)

    case Clients.update_client(client, %{"enabled" => !client.enabled}) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> assign(:clients, Clients.list_clients())
         |> put_flash(:info, "OIDC client updated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update OIDC client")}
    end
  end

  def handle_event("rotate_secret", %{"id" => id}, socket) do
    client = Clients.get_client!(id)

    case Clients.rotate_secret(client) do
      {:ok, {client, secret}} ->
        {:noreply,
         socket
         |> assign(:clients, Clients.list_clients())
         |> assign(:show_form, false)
         |> assign(:editing_client, nil)
         |> assign(:new_secret, secret)
         |> assign(:new_client_id, client.client_id)
         |> put_flash(:info, "Client secret rotated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to rotate client secret")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    client = Clients.get_client!(id)

    case Clients.delete_client(client) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> assign(:clients, Clients.list_clients())
         |> put_flash(:info, "OIDC client deleted successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete OIDC client")}
    end
  end

  defp create_client(socket, params) do
    case Clients.create_client(params, socket.assigns.current_member) do
      {:ok, {client, secret}} ->
        {:noreply,
         socket
         |> assign(:clients, Clients.list_clients())
         |> assign(:show_form, false)
         |> assign(:editing_client, nil)
         |> assign(:form, new_form())
         |> assign(:new_secret, secret)
         |> assign(:new_client_id, client.client_id)
         |> put_flash(:info, "OIDC client created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_client(socket, client, params) do
    case Clients.update_client(client, params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> assign(:clients, Clients.list_clients())
         |> assign(:show_form, false)
         |> assign(:editing_client, nil)
         |> assign(:form, new_form())
         |> put_flash(:info, "OIDC client updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp new_form do
    Client.change_client(%Client{}, %{
      "scopes" => "openid profile email role",
      "enabled" => true
    })
    |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <h1 class="text-2xl font-semibold leading-6 text-gray-900">OIDC Clients</h1>
        <p class="mt-2 text-sm text-gray-700">
          Manage first-party applications that can sign members in through the portal.
        </p>
      </div>
      <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
        <button
          :if={!@show_form and is_nil(@new_secret)}
          id="new-oidc-client"
          phx-click="show_form"
          type="button"
          class="block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          Create OIDC Client
        </button>
      </div>
    </div>

    <div :if={@new_secret} class="mt-6 rounded-md bg-green-50 p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <.icon name="hero-check-circle" class="h-5 w-5 text-green-400" />
        </div>
        <div class="ml-3 min-w-0 flex-1">
          <h2 class="text-sm font-medium text-green-800">
            OIDC Client Secret Created Successfully!
          </h2>
          <div class="mt-2 text-sm text-green-700">
            <p>
              Client ID:
              <code class="rounded bg-green-100 px-1 py-0.5 font-mono text-xs break-all">
                {@new_client_id}
              </code>
            </p>
            <p class="mt-2 font-semibold">
              Client secret (save this now, it won't be shown again):
            </p>
            <div class="mt-2 rounded border bg-green-100 p-2 font-mono text-xs break-all">
              {@new_secret}
            </div>
          </div>
          <div class="mt-4">
            <button
              phx-click="dismiss_secret"
              type="button"
              class="text-sm font-medium text-green-800 underline"
            >
              Dismiss
            </button>
          </div>
        </div>
      </div>
    </div>

    <div :if={@show_form and is_nil(@new_secret)} class="mt-6">
      <div class="rounded-lg border border-gray-200 bg-white p-6">
        <h2 class="text-lg font-medium leading-6 text-gray-900 mb-4">
          {if @editing_client, do: "Edit OIDC Client", else: "Create New OIDC Client"}
        </h2>

        <.simple_form for={@form} id="oidc_client_form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" placeholder="IEEE TAMU Lounge" />

          <.input
            field={@form[:client_id]}
            type="text"
            label="Client ID"
            placeholder="ieee-tamu-lounge"
            readonly={not is_nil(@editing_client)}
            disabled={not is_nil(@editing_client)}
          />
          <p :if={is_nil(@editing_client)} class="-mt-4 text-xs text-gray-500">
            Leave blank to generate a client ID automatically.
          </p>

          <.input
            field={@form[:redirect_uris]}
            type="textarea"
            label="Redirect URIs"
            rows="4"
            placeholder="https://lounge.ieeetamu.org/api/auth/callback"
          />
          <p class="-mt-4 text-xs text-gray-500">
            One URI per line. HTTPS is required except for localhost.
          </p>

          <.input
            field={@form[:scopes]}
            type="text"
            label="Scopes"
            placeholder="openid profile email role"
          />
          <p class="-mt-4 text-xs text-gray-500">
            Supported scopes: openid, profile, email, role. openid is required.
          </p>

          <.input field={@form[:enabled]} type="checkbox" label="Enabled" />

          <div class="flex items-center gap-4">
            <.button phx-disable-with="Saving...">Save OIDC Client</.button>
            <button
              phx-click="hide_form"
              type="button"
              class="text-sm font-medium text-gray-500 hover:text-gray-700"
            >
              Cancel
            </button>
          </div>
        </.simple_form>
      </div>
    </div>

    <div :if={@clients == [] and !@show_form and is_nil(@new_secret)} class="mt-8">
      <.empty_state
        icon="hero-key"
        title="No OIDC clients"
        subtitle="Create a client to let a first-party app sign members in through the portal."
      >
        <button
          phx-click="show_form"
          type="button"
          class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
        >
          <.icon name="hero-plus" class="-ml-0.5 mr-1.5 h-5 w-5" /> Create OIDC Client
        </button>
      </.empty_state>
    </div>

    <div :if={@clients != []} class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th
                    scope="col"
                    class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                  >
                    Client
                  </th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Redirect URIs
                  </th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Scopes
                  </th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Status
                  </th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Last Used
                  </th>
                  <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Created
                  </th>
                  <th class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                    <span class="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                <tr :for={client <- @clients} id={"oidc-client-#{client.id}"}>
                  <td class="py-4 pl-4 pr-3 sm:pl-6">
                    <p class="text-sm font-medium text-gray-900">{client.name}</p>
                    <p class="mt-1 font-mono text-xs text-gray-500 break-all">
                      {client.client_id}
                    </p>
                    <p :if={is_nil(client.created_by_id)} class="mt-1 text-xs text-gray-400">
                      Imported / system client
                    </p>
                  </td>
                  <td class="px-3 py-4 text-sm text-gray-500">
                    <.redirect_uri_list uris={Clients.redirect_uris(client)} />
                  </td>
                  <td class="px-3 py-4 text-sm text-gray-500">
                    <code class="text-xs">{client.scopes}</code>
                  </td>
                  <td class="px-3 py-4 text-sm">
                    <span class={[
                      "inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium",
                      (client.enabled && "bg-green-100 text-green-800") ||
                        "bg-gray-100 text-gray-700"
                    ]}>
                      {if client.enabled, do: "Active", else: "Disabled"}
                    </span>
                  </td>
                  <td class="px-3 py-4 text-sm text-gray-500">
                    {if client.last_used_at,
                      do: Calendar.strftime(client.last_used_at, "%b %d, %Y at %I:%M %p"),
                      else: "Never"}
                  </td>
                  <td class="px-3 py-4 text-sm text-gray-500">
                    {Calendar.strftime(client.inserted_at, "%b %d, %Y")}
                  </td>
                  <td class="relative py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                    <div class="flex justify-end gap-2">
                      <button
                        phx-click="edit"
                        phx-value-id={client.id}
                        type="button"
                        class="rounded-md px-2 py-1 text-indigo-600 hover:bg-indigo-50"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="rotate_secret"
                        phx-value-id={client.id}
                        data-confirm="Rotate this client secret? The old secret will stop working immediately."
                        type="button"
                        class="rounded-md px-2 py-1 text-amber-700 hover:bg-amber-50"
                      >
                        Rotate secret
                      </button>
                      <button
                        phx-click="toggle_enabled"
                        phx-value-id={client.id}
                        type="button"
                        class="rounded-md px-2 py-1 text-gray-600 hover:bg-gray-50"
                      >
                        {if client.enabled, do: "Disable", else: "Enable"}
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={client.id}
                        data-confirm="Delete this OIDC client? Existing integrations will stop working."
                        type="button"
                        class="rounded-md px-2 py-1 text-red-600 hover:bg-red-50"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :uris, :list, required: true

  defp redirect_uri_list(assigns) do
    ~H"""
    <div class="space-y-1">
      <p :for={uri <- Enum.take(@uris, 1)} class="font-mono text-xs break-all">{uri}</p>
      <p :if={length(@uris) > 1} class="text-xs text-gray-400">
        +{length(@uris) - 1} more
      </p>
    </div>
    """
  end
end
