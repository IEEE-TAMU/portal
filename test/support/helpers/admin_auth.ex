defmodule IeeeTamuPortalWeb.TestHelpers.AdminAuth do
  @moduledoc false

  # Helper to add basic auth headers for admin-only routes in LiveView/controller tests
  def admin_auth_conn(conn) do
    {:ok, config} = IeeeTamuPortal.Features.get_config(:admin_panel)
    credentials = Base.encode64("#{config[:username]}:#{config[:password]}")

    Plug.Conn.put_req_header(conn, "authorization", "Basic #{credentials}")
  end
end
