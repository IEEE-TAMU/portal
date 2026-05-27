defmodule IeeeTamuPortalWeb.Auth.AdminAuth do
  import Plug.Conn

  def admin_auth(conn, _opts) do
    case IeeeTamuPortal.Features.get_config(:admin_panel) do
      {:ok, config} ->
        Plug.BasicAuth.basic_auth(conn, username: config[:username], password: config[:password])

      :error ->
        conn
        |> send_resp(503, "Admin panel is not configured")
        |> halt()
    end
  end
end
