defmodule IeeeTamuPortalWeb.Auth.AdminAuth do
  @moduledoc """
  Authorizes access to the admin panel.

  The admin panel is part of the normal member session: officers and admins
  (as stored on `IeeeTamuPortal.Accounts.Member.role`) can access it. Only
  admins can manage other members' roles.

  The checks run in two places:

    * `admin_auth/2` guards ordinary HTTP requests (downloads, check-in, etc.)
    * `on_mount/4` guards LiveView mounts, so a socket connection cannot bypass
      the HTTP check.
  """

  use IeeeTamuPortalWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Accounts.Member

  @doc """
  Plug that requires an authenticated officer or admin.

  Unauthenticated visitors are sent to the member login page (and returned to
  the requested page afterwards). Authenticated members without the officer
  role are sent back to the home page.
  """
  def admin_auth(conn, _opts) do
    case conn.assigns[:current_member] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to access the admin panel.")
        |> maybe_store_return_to()
        |> redirect(to: ~p"/members/login")
        |> halt()

      %Member{} = member ->
        if Member.officer?(member) do
          conn
        else
          conn
          |> put_flash(:error, "You do not have permission to access the admin panel.")
          |> redirect(to: ~p"/")
          |> halt()
        end
    end
  end

  @doc """
  LiveView `on_mount` callback requiring the current member to be an officer or
  admin.
  """
  def on_mount(:ensure_admin, _params, session, socket) do
    socket
    |> mount_current_member(session)
    |> require_role(:officer)
  end

  def on_mount(:ensure_super_admin, _params, session, socket) do
    socket
    |> mount_current_member(session)
    |> require_role(:admin)
  end

  defp mount_current_member(socket, session) do
    Phoenix.Component.assign_new(socket, :current_member, fn ->
      if member_token = session["member_token"] do
        Accounts.get_member_by_session_token(member_token)
      end
    end)
  end

  defp require_role(socket, :officer) do
    member = socket.assigns.current_member

    if Member.officer?(member) do
      {:cont, socket}
    else
      {:halt, deny(socket, member)}
    end
  end

  defp require_role(socket, :admin) do
    member = socket.assigns.current_member

    cond do
      Member.admin?(member) ->
        {:cont, socket}

      Member.officer?(member) ->
        {:halt, deny(socket, "Only admins can manage officer access.", ~p"/admin")}

      true ->
        {:halt, deny(socket, member)}
    end
  end

  defp deny(socket, nil) do
    socket
    |> Phoenix.LiveView.put_flash(:error, "Please log in to access the admin panel.")
    |> Phoenix.LiveView.redirect(to: ~p"/members/login")
  end

  defp deny(socket, _member) do
    deny(socket, "You do not have permission to access this page.", ~p"/")
  end

  defp deny(socket, message, path) do
    socket
    |> Phoenix.LiveView.put_flash(:error, message)
    |> Phoenix.LiveView.redirect(to: path)
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :member_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn
end
