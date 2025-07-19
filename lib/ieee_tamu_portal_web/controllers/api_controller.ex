defmodule IeeeTamuPortalWeb.ApiController do
  use IeeeTamuPortalWeb, :controller

  # defp admin_only(conn, _opts) do
  #   case conn.assigns[:api_key].context do
  #     :admin ->
  #       conn

  #     _ ->
  #       conn
  #       |> put_status(:forbidden)
  #       |> json(%{error: "Forbidden: Admin access required"})
  #       |> halt()
  #   end
  # end

  def ping(conn, _params) do
    json(conn, %{message: "pong"})
  end

  def token_info(conn, _params) do
    api_key = conn.assigns[:api_key]

    response =
      case api_key.context do
        :admin ->
          %{
            context: "admin",
            last_used_at: api_key.last_used_at
          }

        :member ->
          %{
            context: "member",
            member_id: api_key.member_id,
            last_used_at: api_key.last_used_at
          }
      end

    json(conn, response)
  end
end
