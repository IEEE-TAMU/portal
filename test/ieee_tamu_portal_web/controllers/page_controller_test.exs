defmodule IeeeTamuPortalWeb.PageControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    page = html_response(conn, 200)
    assert page =~ "Members"
    assert page =~ "Sponsors"
  end
end
