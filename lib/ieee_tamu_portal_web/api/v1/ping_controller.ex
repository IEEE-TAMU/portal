defmodule IeeeTamuPortalWeb.Api.V1.PingController do
  use IeeeTamuPortalWeb.ApiController

  # alias IeeeTamuPortal.Members
  # # TODO: move logic to Members context
  # alias IeeeTamuPortal.Repo

  tags ["demo"]

  operation :show,
    summary: "Ping the API",
    description: "Returns a simple 'pong' response to check if the API is reachable.",
    responses:
      [
        ok: {"Pong response", "application/json", IeeeTamuPortalWeb.Api.V1.Schemas.PingResponse}
      ] ++ List.flatten(@auth_responses)

  def show(conn, _params) do
    json(conn, %{message: "pong"})
  end
end
