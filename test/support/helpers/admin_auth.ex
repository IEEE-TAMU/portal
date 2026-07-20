defmodule IeeeTamuPortalWeb.TestHelpers.AdminAuth do
  @moduledoc false

  import Plug.Conn, only: [put_req_header: 3]

  # Helper to add basic auth headers for admin-only routes in LiveView/controller tests
  def admin_auth_conn(conn) do
    {:ok, config} = IeeeTamuPortal.Features.get_config(:admin_panel)
    credentials = Base.encode64("#{config[:username]}:#{config[:password]}")

    Plug.Conn.put_req_header(conn, "authorization", "Basic #{credentials}")
  end

  # Helper to add admin API key Bearer auth headers for admin-only API routes
  def admin_api_auth_conn(conn) do
    {:ok, {token, _key}} = IeeeTamuPortal.Api.create_admin_api_key(%{"name" => "Test Admin Key"})
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
