defmodule IeeeTamuPortalWeb.Auth.ApiAuth do
  use IeeeTamuPortalWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias IeeeTamuPortal.Api

  def api_auth(conn, _opts) do
    token = get_req_header(conn, "authorization") |> List.first()

    case token do
      "Bearer " <> provided_token ->
        case Api.verify_api_token(provided_token) do
          {:ok, api_key} ->
            conn
            |> assign(:api_key, api_key)

          {:error, :invalid_token} ->
            conn
            |> unauthorized()
        end

      _ ->
        conn
        |> unauthorized()
    end
  end

  # Admin-only plug must come after api_auth
  def admin_only(conn, _opts) do
    case conn.assigns[:api_key].context do
      :admin ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden: Admin access required"})
        |> halt()
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized: Invalid or missing API token"})
    |> halt()
  end

  @doc """
  When used, invokes `api_auth` plug and sets up security schemes for OpenAPI.
  If `:admin_only` is set to true, it also invokes the `admin_only` plug.
  """
  defmacro __using__(opts) do
    admin_only = Keyword.get(opts, :admin_only, false)

    quote do
      import unquote(__MODULE__), only: [api_auth: 2, admin_only: 2]

      plug :api_auth

      @auth_responses [
        unauthorized:
          {"Unauthorized response", "application/json",
           IeeeTamuPortalWeb.Api.V1.Schemas.UnauthorizedResponse}
      ]

      if unquote(admin_only) do
        plug :admin_only

        @auth_responses [
          forbidden:
            {"Forbidden response", "application/json",
             IeeeTamuPortalWeb.Api.V1.Schemas.ForbiddenResponse}
        ]
      end

      security [%{"authorization" => []}]
    end
  end
end
