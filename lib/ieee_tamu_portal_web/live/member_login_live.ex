defmodule IeeeTamuPortalWeb.MemberLoginLive do
  use IeeeTamuPortalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "member")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in
        <:subtitle>
          Aren't a member yet?
          <.link navigate={~p"/members/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for membership now.
        </:subtitle>
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/members/login"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.link href={~p"/members/reset_password"} class="text-sm font-semibold">
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
