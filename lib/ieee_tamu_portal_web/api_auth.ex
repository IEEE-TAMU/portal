defmodule IeeeTamuPortalWeb.ApiAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias IeeeTamuPortal.Accounts

  def api_auth(conn, _opts) do
    token = get_req_header(conn, "authorization") |> List.first()

    case token do
      "Bearer " <> provided_token ->
        case Accounts.verify_api_token(provided_token) do
          {:ok, _api_key} ->
            conn

          {:error, :invalid_token} ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized: Invalid or missing API token"})
    |> halt()
  end
end
