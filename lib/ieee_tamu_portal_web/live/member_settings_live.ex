defmodule IeeeTamuPortalWeb.MemberSettingsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member |> Accounts.preload_member_auth_methods()
    password_changeset = Accounts.change_member_password(member)

    socket =
      socket
      |> assign(:current_member, member)
      |> assign(:current_password, nil)
      |> assign(:current_email, member.email)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  defp discord_linked?(assigns) do
    auth_methods = assigns.current_member.secondary_auth_methods || []
    Enum.any?(auth_methods, &(&1.provider == :discord))
  end

  defp google_linked?(assigns) do
    auth_methods = assigns.current_member.secondary_auth_methods || []
    Enum.any?(auth_methods, &(&1.provider == :google))
  end

  defp get_discord_username(assigns) do
    auth_methods = assigns.current_member.secondary_auth_methods || []

    case Enum.find(auth_methods, &(&1.provider == :discord)) do
      nil -> ""
      auth_method -> auth_method.preferred_username || auth_method.email || "Unknown"
    end
  end

  defp get_google_email(assigns) do
    auth_methods = assigns.current_member.secondary_auth_methods || []

    case Enum.find(auth_methods, &(&1.provider == :google)) do
      nil -> ""
      auth_method -> auth_method.email || "Unknown"
    end
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "member" => member_params} = params

    password_form =
      socket.assigns.current_member
      |> Accounts.change_member_password(member_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "member" => member_params} = params
    member = socket.assigns.current_member

    case Accounts.update_member_password(member, password, member_params) do
      {:ok, member} ->
        password_form =
          member
          |> Accounts.change_member_password(member_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("unlink_discord", _params, socket) do
    member = socket.assigns.current_member

    case Accounts.unlink_auth_method(member, :discord) do
      {:ok, auth_method} ->
        # do not use preload since it lazily does not remove the discord auth method from current_member without a DB query
        updated_member =
          member
          |> Map.update!(:secondary_auth_methods, fn auth_methods ->
            Enum.reject(auth_methods, &(&1.provider == :discord))
          end)

        # Remove the Member role from the Discord account that was just unlinked
        discord_user_id = auth_method.sub
        IeeeTamuPortal.Discord.Client.remove_role(discord_user_id, "Member")

        socket =
          socket
          |> assign(:current_member, updated_member)
          |> put_flash(:info, "Discord account unlinked successfully!")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Discord account not found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to unlink Discord account.")}
    end
  end

  @impl true
  def handle_event("unlink_google", _params, socket) do
    member = socket.assigns.current_member

    case Accounts.unlink_auth_method(member, :google) do
      {:ok, _auth_method} ->
        # do not use preload since it lazily does not remove the google auth method from current_member without a DB query
        updated_member =
          member
          |> Map.update!(:secondary_auth_methods, fn auth_methods ->
            Enum.reject(auth_methods, &(&1.provider == :google))
          end)

        socket =
          socket
          |> assign(:current_member, updated_member)
          |> put_flash(:info, "Google account unlinked successfully!")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Google account not found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to unlink Google account.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Settings for {@current_member.email}</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.header class="text-lg">
          External Accounts
        </.header>
        <div class="mt-6">
          <%= if discord_linked?(assigns) do %>
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
              <div class="flex items-center space-x-3">
                <div class="w-8 h-8 aspect-square bg-indigo-600 rounded flex-none flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419-.019 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-medium text-gray-900">Discord</p>
                  <p class="text-sm text-gray-500">
                    Connected as {get_discord_username(assigns)}
                  </p>
                </div>
              </div>
              <.button
                type="button"
                phx-click="unlink_discord"
                class="bg-red-600 hover:bg-red-700"
                data-confirm="Are you sure you want to unlink your Discord account?"
              >
                Unlink
              </.button>
            </div>
          <% else %>
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
              <div class="flex items-center space-x-3">
                <div class="w-8 h-8 aspect-square bg-gray-400 rounded flex-none flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419-.0189 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-medium text-gray-900">Discord</p>
                  <p class="text-sm text-gray-500">Not connected</p>
                </div>
              </div>
              <.link
                href={~p"/auth/discord"}
                class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Connect
              </.link>
            </div>
          <% end %>

          <%= if google_linked?(assigns) do %>
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg mt-4">
              <div class="flex items-center space-x-3">
                <div class="w-8 h-8 aspect-square bg-red-600 rounded flex-none flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-medium text-gray-900">Google</p>
                  <p class="text-sm text-gray-500">
                    Connected as {get_google_email(assigns)}
                  </p>
                </div>
              </div>
              <.button
                type="button"
                phx-click="unlink_google"
                class="bg-red-600 hover:bg-red-700"
                data-confirm="Are you sure you want to unlink your Google account?"
              >
                Unlink
              </.button>
            </div>
          <% else %>
            <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg mt-4">
              <div class="flex items-center space-x-3">
                <div class="w-8 h-8 aspect-square bg-gray-400 rounded flex-none flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-medium text-gray-900">Google</p>
                  <p class="text-sm text-gray-500">Not connected (Must use @tamu.edu account)</p>
                </div>
              </div>
              <.link
                href={~p"/auth/google"}
                class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              >
                Connect
              </.link>
            </div>
          <% end %>
        </div>
      </div>

      <div class="pt-12">
        <.header class="text-lg">
          Change password
        </.header>
        <div class="mt-6">
          <.simple_form
            for={@password_form}
            id="password_form"
            action={~p"/members/login?_action=password_updated"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_member_email"
              value={@current_email}
            />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Password</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end
end
