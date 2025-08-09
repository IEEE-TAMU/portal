defmodule IeeeTamuPortalWeb.Api.V1.PingControllerTest do
  use IeeeTamuPortalWeb.ConnCase

  describe "GET /api/v1/ping" do
    test "returns pong response", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/ping")

      assert json_response(conn, 200) == %{"message" => "pong"}
    end

    test "returns correct content type", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/ping")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "ping endpoint is accessible without authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/ping")

      assert conn.status == 200
      assert json_response(conn, 200) == %{"message" => "pong"}
    end
  end
end
