defmodule IeeeTamuPortalWeb.OAuthController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Accounts
  alias Assent.Strategy.Discord
  alias Assent.Strategy.Google

  @doc """
  Initiates OAuth flow for the specified provider (discord or google)
  """
  def authorize(conn, %{"provider" => "discord"}) do
    discord_config()
    |> Discord.authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:oauth_session_params, session_params)
        |> redirect(external: url)

      {:error, _error} ->
        # Different error handling based on whether user is authenticated
        redirect_location = if conn.assigns[:current_member], do: ~p"/members/settings", else: ~p"/members/login"
        error_message = if conn.assigns[:current_member],
                          do: "Failed to initiate Discord authentication. Please try again.",
                          else: "Failed to initiate Discord login. Please try again."

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_location)
    end
  end

  def authorize(conn, %{"provider" => "google"}) do
    google_config()
    |> Google.authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:oauth_session_params, session_params)
        |> redirect(external: url)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to initiate Google authentication. Please try again.")
        |> redirect(to: ~p"/members/settings")
    end
  end

  @doc """
  Handles OAuth callback from Discord
  """

  def callback(conn, %{"provider" => "discord", "error" => _error}) do
    # Different error handling based on whether user is authenticated
    redirect_location = if conn.assigns[:current_member], do: ~p"/members/settings", else: ~p"/members/login"
    error_message = if conn.assigns[:current_member],
                      do: "Discord authentication was cancelled or failed.",
                      else: "Discord login was cancelled or failed."

    conn
    |> put_flash(:error, error_message)
    |> redirect(to: redirect_location)
  end

  def callback(conn, %{"provider" => "discord"} = params) do
    session_params = get_session(conn, :oauth_session_params) || %{}
    conn = delete_session(conn, :oauth_session_params)

    discord_config()
    |> Keyword.put(:session_params, session_params)
    |> Discord.callback(params)
    |> case do
      {:ok, info} ->
        # Check if user is authenticated to determine behavior
        if conn.assigns[:current_member] do
          handle_discord_linking(conn, info)
        else
          handle_discord_login(conn, info)
        end

      {:error, _error} ->
        # Different error handling based on whether user is authenticated
        redirect_location = if conn.assigns[:current_member], do: ~p"/members/settings", else: ~p"/members/login"
        error_message = if conn.assigns[:current_member],
                          do: "Discord authentication failed. Please try again.",
                          else: "Discord login failed. Please try again."

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_location)
    end
  end

  def callback(conn, %{"provider" => "google", "error" => _error}) do
    conn
    |> put_flash(:error, "Google authentication was cancelled or failed.")
    |> redirect(to: ~p"/members/settings")
  end

  def callback(conn, %{"provider" => "google"} = params) do
    session_params = get_session(conn, :oauth_session_params) || %{}
    conn = delete_session(conn, :oauth_session_params)

    google_config()
    |> Keyword.put(:session_params, session_params)
    |> Google.callback(params)
    |> case do
      {:ok, user_info} ->
        handle_google_auth(conn, user_info)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Google authentication failed. Please try again.")
        |> redirect(to: ~p"/members/settings")
    end
  end

  defp handle_google_auth(conn, %{user: user_info}) do
    # Check if the email ends with @tamu.edu
    email = user_info["email"] || ""
    
    unless String.ends_with?(email, "@tamu.edu") do
      conn
      |> put_flash(:error, "You must use a @tamu.edu Google account to link your account.")
      |> redirect(to: ~p"/members/settings")
    else
      handle_successful_auth(conn, %{user: user_info}, :google)
    end
  end

  defp handle_successful_auth(conn, %{user: user_info}, provider) do
    current_member = conn.assigns.current_member

    member_auth_attrs =
      Map.take(user_info, ~w[sub preferred_username email email_verified])
      |> Map.put("provider", provider)

    case Accounts.link_auth_method(current_member, member_auth_attrs) do
      {:ok, _auth_method} ->
        # Trigger Discord role synchronization after successful Discord linking
        if provider == :discord do
          IeeeTamuPortal.Discord.RoleSyncService.sync_member(current_member)
        end

        conn
        |> put_flash(:info, "External account linked successfully!")
        |> redirect(to: ~p"/members/settings")

      {:error, %Ecto.Changeset{errors: errors}} ->
        error_message =
          case Keyword.get(errors, :provider) do
            {_, [constraint: :unique, constraint_name: _]} ->
              "This external account is already linked to another member."

            _ ->
              "Failed to link external account. Please try again."
          end

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: ~p"/members/settings")

      {:error, _err} ->
        conn
        |> put_flash(:error, "Failed to link external account. Please try again.")
        |> redirect(to: ~p"/members/settings")
    end
  end

  defp handle_discord_login(conn, %{user: user_info}) do
    discord_sub = user_info["sub"]

    case Accounts.get_member_by_discord_sub(discord_sub) do
      nil ->
        conn
        |> put_flash(:error, "No account found linked to this Discord account. Please create an account first and link your Discord account in settings.")
        |> redirect(to: ~p"/members/login")

      member ->
        conn
        |> put_flash(:info, "Successfully logged in with Discord!")
        |> IeeeTamuPortalWeb.Auth.MemberAuth.log_in_member(member)
    end
  end

  defp discord_config do
    config = Application.get_env(:ieee_tamu_portal, :discord_oauth)

    [
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: url(~p"/auth/discord/callback")
      # authorization_params: [scope: "identify"] # do not need email scope for linking
    ]
  end

  defp google_config do
    config = Application.get_env(:ieee_tamu_portal, :google_oauth)

    [
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: url(~p"/auth/google/callback")
    ]
  end
end
