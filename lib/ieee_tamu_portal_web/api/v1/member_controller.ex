defmodule IeeeTamuPortalWeb.Api.V1.MemberController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortalWeb.Api.V1.Schemas

  require Logger

  tags ["members"]

  api_operation :index,
    summary: "Get members",
    description:
      "Fetches members. Admins can see all members, regular members can only see themselves.",
    responses: [
      ok: {"Members list", "application/json", Schemas.MemberListResponse}
    ] do
    fn conn, _params, api_key ->
      case api_key.context do
        :admin ->
          members = Accounts.get_all_members_with_info()
          members = Enum.map(members, &Schemas.Member.from_struct/1)
          json(conn, members)

        :member ->
          if api_key.member_id do
            case Accounts.get_member_with_info(api_key.member_id) do
              nil ->
                json(conn, [])

              member ->
                json(conn, [Schemas.Member.from_struct(member)])
            end
          else
            json(conn, [])
          end
      end
    end
  end

  api_operation :show,
    summary: "Get member by ID",
    description:
      "Fetches a specific member by ID. Admins can view any member, regular members can only view themselves.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :path,
        name: "id",
        required: true,
        schema: %OpenApiSpex.Schema{type: :integer}
      }
    ],
    responses: [
      ok: {"Member details", "application/json", Schemas.Member},
      not_found: {"Member not found", "application/json", Schemas.NotFoundResponse}
    ] do
    fn conn, params, api_key ->
      member_id = String.to_integer(params["id"])

      case api_key.context do
        :admin ->
          case Accounts.get_member_with_info(member_id) do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(Schemas.NotFoundResponse.default("Member not found"))
              |> halt()

            member ->
              json(conn, Schemas.Member.from_struct(member))
          end

        :member ->
          if api_key.member_id == member_id do
            member = Accounts.get_member_with_info(member_id)
            json(conn, Schemas.Member.from_struct(member))
          else
            conn
            |> put_status(:forbidden)
            |> json(%{error: "You can only view your own profile"})
            |> halt()
          end
      end
    end
  end
end
