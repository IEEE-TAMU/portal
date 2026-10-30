defmodule IeeeTamuPortalWeb.TestHelpers.AdminAuth do
  @moduledoc false

  import Plug.Conn, only: [put_req_header: 3]

  # Logs the connection in as an admin member. The admin panel is session
  # based now, so tests no longer need an Authorization header.
  def admin_auth_conn(conn) do
    member = IeeeTamuPortal.AccountsFixtures.admin_member_fixture()
    IeeeTamuPortalWeb.ConnCase.log_in_member(conn, member)
  end

  # Logs the connection in as an officer (admin panel access, but no role
  # management).
  def officer_auth_conn(conn) do
    member = IeeeTamuPortal.AccountsFixtures.officer_member_fixture()
    IeeeTamuPortalWeb.ConnCase.log_in_member(conn, member)
  end

  # Helper to add admin API key Bearer auth headers for admin-only API routes
  def admin_api_auth_conn(conn) do
    {:ok, {token, _key}} = IeeeTamuPortal.Api.create_admin_api_key(%{"name" => "Test Admin Key"})
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
