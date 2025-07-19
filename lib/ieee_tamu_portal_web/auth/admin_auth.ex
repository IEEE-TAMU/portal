defmodule IeeeTamuPortalWeb.Auth.AdminAuth do
  defp username, do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:username]
  defp password, do: Application.fetch_env!(:ieee_tamu_portal, __MODULE__)[:password]

  def admin_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, username: username(), password: password())
  end
end
