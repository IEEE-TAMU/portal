defmodule IeeeTamuPortal.Discord.Client do
  @moduledoc """
  Discord Bot API client for managing Discord roles.

  This module provides functions to interact with the Discord bot API
  to manage member roles based on their authentication and payment status.
  """

  require Logger

  @doc """
  Checks if the Discord bot is healthy.

  Returns {:ok, response} or {:error, reason}.
  """
  def health_check do
    case Req.get(discord_bot_url("/health")) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Discord bot health check failed: #{status_code} - #{inspect(body)}")
        {:error, "Discord bot unhealthy: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Discord bot: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets all roles for a Discord user.

  Returns {:ok, user_data} or {:error, reason}.
  """
  def get_user_roles(discord_user_id) do
    url = discord_bot_url("/roles?userId=#{discord_user_id}")

    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status_code, body: body}} ->
        Logger.error("Failed to get user roles: #{status_code} - #{inspect(body)}")
        {:error, "Failed to get roles: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Discord bot: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Adds a role to a Discord user.

  Returns {:ok, response} or {:error, reason}.
  """
  def add_role(discord_user_id, role_name) do
    url = discord_bot_url("/roles/manage")
    body = %{userId: discord_user_id, roleName: role_name}

    case Req.put(url, json: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        Logger.info("Successfully added #{role_name} role to Discord user #{discord_user_id}")
        {:ok, response_body}

      {:ok, %Req.Response{status: status_code, body: response_body}} ->
        Logger.error("Failed to add role: #{status_code} - #{inspect(response_body)}")
        {:error, "Failed to add role: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Discord bot: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Removes a role from a Discord user.

  Returns {:ok, response} or {:error, reason}.
  """
  def remove_role(discord_user_id, role_name) do
    url = discord_bot_url("/roles/manage")
    body = %{userId: discord_user_id, roleName: role_name}

    case Req.delete(url, json: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        Logger.info("Successfully removed #{role_name} role from Discord user #{discord_user_id}")
        {:ok, response_body}

      {:ok, %Req.Response{status: status_code, body: response_body}} ->
        Logger.error("Failed to remove role: #{status_code} - #{inspect(response_body)}")
        {:error, "Failed to remove role: #{status_code}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Discord bot: #{inspect(reason)}")
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Checks if a Discord user has a specific role.

  Returns {:ok, boolean} or {:error, reason}.
  """
  def has_role?(discord_user_id, role_name) do
    case get_user_roles(discord_user_id) do
      {:ok, %{"success" => true, "roles" => roles}} ->
        has_role = Enum.any?(roles, fn role -> role["name"] == role_name end)
        {:ok, has_role}

      {:ok, %{"success" => false, "message" => message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp discord_bot_url(path) do
    base_url = Application.fetch_env!(:ieee_tamu_portal, :discord_bot_url)
    base_url <> path
  end
end
