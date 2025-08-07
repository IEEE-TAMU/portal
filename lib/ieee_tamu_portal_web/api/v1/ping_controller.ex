defmodule IeeeTamuPortalWeb.Api.V1.PingController do
  use IeeeTamuPortalWeb.ApiController

  tags ["demo"]

  insecure_operation :show,
    summary: "Ping the API",
    description:
      "Returns a simple 'pong' response to check if the API is reachable. No authentication required.",
    responses: [
      ok: {"Pong response", "application/json", IeeeTamuPortalWeb.Api.V1.Schemas.PingResponse}
    ] do
    fn conn, _params ->
      json(conn, %{message: "pong"})
    end
  end
end
