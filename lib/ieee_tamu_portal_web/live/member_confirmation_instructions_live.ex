defmodule IeeeTamuPortalWeb.MemberConfirmationInstructionsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if member = socket.assigns.current_member do
      if member.confirmed_at do
        # If the member is logged in and already confirmed, redirect to the home page
        {:ok,
         socket
         |> put_flash(:info, "Your account is already confirmed.")
         |> redirect(to: ~p"/")}
      else
        # If the member is logged in but not confirmed, show the confirmation instructions page
        {:ok, assign(socket, form: to_form(%{"email" => member.email}, as: "member"))}
      end
    else
      {:ok, assign(socket, form: to_form(%{}, as: "member"))}
    end
  end

  @impl true
  def handle_event("send_instructions", %{"member" => %{"email" => email}}, socket) do
    if member = Accounts.get_member_by_email(email) do
      Accounts.deliver_member_confirmation_instructions(
        member,
        &url(~p"/members/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply, put_flash(socket, :info, info)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        <%= if @current_member do %>
          Account Pending Confirmation
        <% else %>
          Confirm Your Account
        <% end %>
        <:subtitle>No confirmation instructions received?</:subtitle>
        <:subtitle>We'll send a new confirmation link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
