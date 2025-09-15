defmodule IeeeTamuPortalWeb.Api.V1.DiscordRolesController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.{Accounts}
  alias IeeeTamuPortal.Discord.Client
  alias IeeeTamuPortalWeb.Api.V1.Schemas

  require Logger

  tags ["members"]

  admin_operation :index,
    summary: "Get Discord roles for member",
    description: "Returns all Discord roles for the member identified by email. Requires admin.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :query,
        name: "email",
        required: true,
        description: "Member email",
        schema: %OpenApiSpex.Schema{type: :string, format: :email}
      }
    ],
    responses: [
      ok: {"Roles", "application/json", Schemas.DiscordRolesResponse},
      not_found: {"Member or Discord not linked", "application/json", Schemas.NotFoundResponse}
    ] do
    fn conn, params, _api_key ->
      with email when is_binary(email) <- params["email"],
           %Accounts.Member{} = member <- Accounts.get_member_by_email(email),
           member <- Accounts.preload_member_auth_methods(member),
           %Accounts.AuthMethod{sub: discord_user_id, provider: :discord} <-
             Enum.find(member.secondary_auth_methods, :no_discord, &(&1.provider == :discord)),
           {:ok, body} <- Client.get_user_roles(discord_user_id) do
        json(conn, Schemas.DiscordRolesResponse.from_client(body))
      else
        nil ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Member not found"))

        :no_discord ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Discord not linked for member"))

        {:error, reason} ->
          conn
          |> put_status(:bad_gateway)
          |> json(%{error: "Discord bot error: #{reason}"})
      end
    end
  end

  admin_operation :create,
    summary: "Add Discord role to member",
    description:
      "Adds a Discord role to the member identified by email. Requires admin privileges.",
    request_body: %OpenApiSpex.RequestBody{
      required: true,
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: Schemas.DiscordRoleManageRequest
        }
      }
    },
    responses: [
      ok: {"Role added", "application/json", Schemas.DiscordRoleManageResponse},
      not_found: {"Member or Discord not linked", "application/json", Schemas.NotFoundResponse}
    ] do
    fn conn, params, _api_key ->
      with %{"email" => email, "role" => role} <- params,
           %Accounts.Member{} = member <- Accounts.get_member_by_email(email),
           member <- Accounts.preload_member_auth_methods(member),
           %Accounts.AuthMethod{sub: discord_user_id, provider: :discord} <-
             Enum.find(member.secondary_auth_methods, :no_discord, &(&1.provider == :discord)),
           {:ok, body} <- Client.add_role(discord_user_id, role) do
        json(conn, Schemas.DiscordRoleManageResponse.from_client(body))
      else
        nil ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Member not found"))

        :no_discord ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Discord not linked for member"))

        {:error, reason} ->
          conn
          |> put_status(:bad_gateway)
          |> json(%{error: "Discord bot error: #{reason}"})
      end
    end
  end

  admin_operation :delete,
    summary: "Remove Discord role from member",
    description:
      "Removes a Discord role from the member identified by email. Requires admin privileges.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :query,
        name: "email",
        required: true,
        schema: %OpenApiSpex.Schema{type: :string, format: :email}
      },
      %OpenApiSpex.Parameter{
        in: :query,
        name: "role",
        required: true,
        schema: %OpenApiSpex.Schema{type: :string}
      }
    ],
    responses: [
      ok: {"Role removed", "application/json", Schemas.DiscordRoleManageResponse},
      not_found: {"Member or Discord not linked", "application/json", Schemas.NotFoundResponse}
    ] do
    fn conn, params, _api_key ->
      with email when is_binary(email) <- params["email"],
           role when is_binary(role) <- params["role"],
           %Accounts.Member{} = member <- Accounts.get_member_by_email(email),
           member <- Accounts.preload_member_auth_methods(member),
           %Accounts.AuthMethod{sub: discord_user_id, provider: :discord} <-
             Enum.find(member.secondary_auth_methods, :no_discord, &(&1.provider == :discord)),
           {:ok, body} <- Client.remove_role(discord_user_id, role) do
        json(conn, Schemas.DiscordRoleManageResponse.from_client(body))
      else
        nil ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Member not found"))

        :no_discord ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.NotFoundResponse.default("Discord not linked for member"))

        {:error, reason} ->
          conn
          |> put_status(:bad_gateway)
          |> json(%{error: "Discord bot error: #{reason}"})
      end
    end
  end
end
