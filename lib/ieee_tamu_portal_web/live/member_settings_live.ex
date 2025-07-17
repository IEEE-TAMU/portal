defmodule IeeeTamuPortalWeb.MemberSettingsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member
    password_changeset = Accounts.change_member_password(member)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:current_email, member.email)
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
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
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Change password
    </.header>
    <div>
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
    """
  end
end
