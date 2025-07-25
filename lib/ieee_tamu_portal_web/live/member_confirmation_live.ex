defmodule IeeeTamuPortalWeb.MemberConfirmationLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts
  @impl true
  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "member")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  @impl true
  # Do not log in the member after confirmation to avoid a
  # leaked token giving the member access to the account.
  def handle_event("confirm_account", %{"member" => %{"token" => token}}, socket) do
    case Accounts.confirm_member(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member confirmed successfully.")
         |> redirect(to: ~p"/members/info")}

      :error ->
        # If there is a current member and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the member themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_member: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/members/info")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "Member confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end

  @impl true
  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
