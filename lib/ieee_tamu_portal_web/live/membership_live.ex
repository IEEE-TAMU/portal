defmodule IeeeTamuPortalWeb.MembershipLive do
  use IeeeTamuPortalWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Membership information
      <:subtitle>Placeholder</:subtitle>
    </.header>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
