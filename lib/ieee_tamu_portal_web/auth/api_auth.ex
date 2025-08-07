defmodule IeeeTamuPortalWeb.Auth.ApiAuth do
  use IeeeTamuPortalWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias IeeeTamuPortal.Api

  @header "authorization"

  @doc """
  Extracts and verifies API token from the connection.
  Returns {:ok, api_key, conn} on success, {:error, reason, conn} on failure.
  """
  def get_api_key(conn) do
    token = get_req_header(conn, @header) |> List.first()

    case token do
      "Bearer " <> provided_token ->
        case Api.verify_api_token(provided_token) do
          {:ok, api_key} ->
            {:ok, api_key, conn}

          {:error, :invalid_token} ->
            conn =
              conn
              |> put_status(:unauthorized)
              |> json(IeeeTamuPortalWeb.Api.V1.Schemas.UnauthorizedResponse.default())
              |> halt()

            {:error, :invalid_token, conn}
        end

      _ ->
        conn =
          conn
          |> put_status(:unauthorized)
          |> json(IeeeTamuPortalWeb.Api.V1.Schemas.UnauthorizedResponse.default())
          |> halt()

        {:error, :missing_token, conn}
    end
  end

  @doc """
  Extracts API token and verifies admin access.
  Returns {:ok, api_key, conn} on success, {:error, reason, conn} on failure.
  """
  def require_admin(conn) do
    case get_api_key(conn) do
      {:ok, api_key, conn} ->
        case api_key.context do
          :admin ->
            {:ok, api_key, conn}

          _ ->
            conn =
              conn
              |> put_status(:forbidden)
              |> json(IeeeTamuPortalWeb.Api.V1.Schemas.ForbiddenResponse.default())
              |> halt()

            {:error, :not_admin, conn}
        end

      {:error, reason, conn} ->
        {:error, reason, conn}
    end
  end

  def standard_auth_responses do
    [
      unauthorized:
        {"Unauthorized response", "application/json",
         IeeeTamuPortalWeb.Api.V1.Schemas.UnauthorizedResponse}
    ]
  end

  def admin_auth_responses do
    standard_auth_responses() ++
      [
        forbidden:
          {"Forbidden response", "application/json",
           IeeeTamuPortalWeb.Api.V1.Schemas.ForbiddenResponse}
      ]
  end

  def auth_header do
    @header
  end
end
