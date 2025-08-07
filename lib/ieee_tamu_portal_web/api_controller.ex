defmodule IeeeTamuPortalWeb.ApiController do
  @moduledoc """
  Enhanced API controller base with simplified authentication and automatic response handling.

  Usage:
    # API controller with authentication operations available
    use IeeeTamuPortalWeb.ApiController

  Features:
  - Automatic auth response injection for OpenAPI specs for secure operations
  - Simplified admin-only endpoint handling with admin_operation macro
  - Clean interface without manual response attribute management
  - Combined operation declaration and implementation macros
  - Explicit choice between secure and insecure operations
  - API key automatically passed as third parameter for secure operations

  Examples:
    # Secure endpoint (requires authentication)
    api_operation :get_user_data,
      summary: "Get user data",
      responses: [ok: {"User data", "application/json", Schema}] do
      fn conn, params, api_key ->
        # implementation with explicit conn, params, and api_key
      end
    end

    # Admin-only endpoint (requires admin authentication)
    admin_operation :admin_action,
      summary: "Admin action",
      responses: [created: {"Created", "application/json", Schema}] do
      fn conn, params, api_key ->
        # implementation - automatically protected as admin-only
      end
    end

    # Insecure endpoint (no authentication required)
    insecure_operation :public_info,
      summary: "Get public info",
      responses: [ok: {"Info", "application/json", Schema}] do
      fn conn, params ->
        # implementation - no authentication required (2-arity)
      end
    end
  """

  defmacro __using__(_opts) do
    quote do
      use IeeeTamuPortalWeb, :api_controller

      import IeeeTamuPortalWeb.ApiController,
        only: [
          api_operation: 3,
          admin_operation: 3,
          insecure_operation: 3
        ]
    end
  end

  @doc """
  Macro for defining a standard API operation with automatic auth response injection.

  Usage:
    api_operation :index,
      summary: "Get items",
      responses: [ok: {"Items", "application/json", Schema}] do
      fn conn, params, api_key ->
        # implementation here - api_key is automatically extracted from conn.assigns
      end
    end
  """
  defmacro api_operation(name, opts, do: body) do
    quote do
      # Extract responses and add auth responses
      {responses, other_opts} = Keyword.pop(unquote(opts), :responses, [])
      final_responses = responses ++ IeeeTamuPortalWeb.Auth.ApiAuth.standard_auth_responses()

      final_opts =
        Keyword.put(other_opts, :responses, final_responses)
        |> Keyword.put(:security, [%{IeeeTamuPortalWeb.Auth.ApiAuth.auth_header() => []}])

      # Declare the operation
      operation unquote(name), final_opts

      # Define the function using the provided body, extracting api_key from conn.assigns
      def unquote(name)(conn, params) do
        case IeeeTamuPortalWeb.Auth.ApiAuth.get_api_key(conn) do
          {:ok, api_key, conn} ->
            unquote(body).(conn, params, api_key)

          {:error, _, conn} ->
            conn
        end
      end
    end
  end

  @doc """
  Macro for defining an insecure API operation without authentication.

  Usage:
    insecure_operation :public_info,
      summary: "Get public info",
      responses: [ok: {"Public info", "application/json", Schema}] do
      fn conn, params ->
        # implementation here - no authentication required
      end
    end
  """
  defmacro insecure_operation(name, opts, do: body) do
    quote do
      # Use responses as-is without adding auth responses
      operation unquote(name), unquote(opts)

      # Define the function using the provided body
      def unquote(name)(conn, params) do
        unquote(body).(conn, params)
      end
    end
  end

  @doc """
  Macro for defining an admin-only API operation with automatic admin auth response injection.

  Usage:
    admin_operation :create,
      summary: "Create item",
      responses: [created: {"Created", "application/json", Schema}] do
      fn conn, params, api_key ->
        # implementation here - automatically protected as admin-only
        # api_key is automatically extracted from conn.assigns
      end
    end
  """
  defmacro admin_operation(name, opts, do: body) do
    quote do
      # Extract responses and add admin auth responses
      {responses, other_opts} = Keyword.pop(unquote(opts), :responses, [])
      final_responses = responses ++ IeeeTamuPortalWeb.Auth.ApiAuth.admin_auth_responses()

      final_opts =
        Keyword.put(other_opts, :responses, final_responses)
        |> Keyword.put(:security, [%{IeeeTamuPortalWeb.Auth.ApiAuth.auth_header() => []}])

      # Declare the operation
      operation unquote(name), final_opts

      # Define the function with admin protection
      def unquote(name)(conn, params) do
        case IeeeTamuPortalWeb.Auth.ApiAuth.require_admin(conn) do
          {:ok, api_key, conn} ->
            unquote(body).(conn, params, api_key)

          {:error, _, conn} ->
            conn
        end
      end
    end
  end
end
