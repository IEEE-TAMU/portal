defmodule IeeeTamuPortalWeb.ApiController do
  use IeeeTamuPortalWeb, :controller

  def ping(conn, _params) do
    json(conn, %{message: "pong"})
  end
end
