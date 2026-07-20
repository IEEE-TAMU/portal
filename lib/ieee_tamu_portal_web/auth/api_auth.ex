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
        case extract_token_from_query(conn) do
          {token, conn} ->
            case Api.verify_api_token(token) do
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

          nil ->
            conn =
              conn
              |> put_status(:unauthorized)
              |> json(IeeeTamuPortalWeb.Api.V1.Schemas.UnauthorizedResponse.default())
              |> halt()

            {:error, :missing_token, conn}
        end
    end
  end

  @doc """
  Optionally extracts an admin API key from the connection without halting on failure.
  Checks the Authorization header first, then falls back to the `token` query parameter.
  If found in the query string, the token is removed from the conn.

  Returns {:ok, api_key, conn} if a valid admin key is found, {:error, conn} otherwise.
  """
  def try_get_admin_key(conn) do
    case get_req_header(conn, @header) |> List.first() do
      "Bearer " <> provided_token ->
        verify_admin_token(provided_token, conn)

      _ ->
        case extract_token_from_query(conn) do
          {token, conn} -> verify_admin_token(token, conn)
          nil -> {:error, conn}
        end
    end
  end

  defp verify_admin_token(token, conn) do
    case Api.verify_api_token(token) do
      {:ok, api_key = %{context: :admin}} ->
        {:ok, api_key, conn}

      _ ->
        {:error, conn}
    end
  end

  defp extract_token_from_query(conn) do
    case conn.query_string do
      nil -> nil
      "" -> nil
      qs ->
        case URI.decode_query(qs) do
          %{"token" => token} = params ->
            rest = Map.delete(params, "token")
            new_qs = if rest == %{}, do: "", else: URI.encode_query(rest)
            conn = %{conn | query_string: new_qs}
            {token, conn}

          _ ->
            nil
        end
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
