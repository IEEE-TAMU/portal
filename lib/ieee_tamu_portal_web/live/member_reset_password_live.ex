defmodule IeeeTamuPortalWeb.MemberResetPasswordLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Reset Password</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:password]} type="password" label="New password" required />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />
        <:actions>
          <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/members/register"}>Register</.link>
        | <.link href={~p"/members/login"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_member_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{member: member} ->
          Accounts.change_member_password(member)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the member after reset password to avoid a
  # leaked token giving the member access to the account.
  def handle_event("reset_password", %{"member" => member_params}, socket) do
    case Accounts.reset_member_password(socket.assigns.member, member_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/members/login")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"member" => member_params}, socket) do
    changeset = Accounts.change_member_password(socket.assigns.member, member_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_member_and_token(socket, %{"token" => token}) do
    if member = Accounts.get_member_by_reset_password_token(token) do
      assign(socket, member: member, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "member"))
  end
end
