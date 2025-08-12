defmodule IeeeTamuPortalWeb.TestHelpers.AdminAuth do
  @moduledoc false

  # Helper to add basic auth headers for admin-only routes in LiveView/controller tests
  def admin_auth_conn(conn) do
    username =
      Application.fetch_env!(:ieee_tamu_portal, IeeeTamuPortalWeb.Auth.AdminAuth)[:username]

    password =
      Application.fetch_env!(:ieee_tamu_portal, IeeeTamuPortalWeb.Auth.AdminAuth)[:password]

    credentials = Base.encode64("#{username}:#{password}")
    Plug.Conn.put_req_header(conn, "authorization", "Basic #{credentials}")
  end
end
