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
        {redirect_location, error_message} =
          if conn.assigns[:current_member] do
            {~p"/members/settings",
             "Failed to initiate Discord authentication. Please try again."}
          else
            {~p"/members/login", "Failed to initiate Discord login. Please try again."}
          end

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
        # Different error handling based on whether user is authenticated
        {redirect_location, error_message} =
          if conn.assigns[:current_member] do
            {~p"/members/settings", "Failed to initiate Google authentication. Please try again."}
          else
            {~p"/members/login", "Failed to initiate Google login. Please try again."}
          end

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_location)
    end
  end

  @doc """
  Handles OAuth callback from Discord
  """

  def callback(conn, %{"provider" => "discord", "error" => _error}) do
    # Different error handling based on whether user is authenticated
    {redirect_location, error_message} =
      if conn.assigns[:current_member] do
        {~p"/members/settings", "Discord authentication was cancelled or failed."}
      else
        {~p"/members/login", "Discord login was cancelled or failed."}
      end

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
          handle_successful_auth(conn, info, :discord)
        else
          handle_discord_login(conn, info)
        end

      {:error, _error} ->
        # Different error handling based on whether user is authenticated
        {redirect_location, error_message} =
          if conn.assigns[:current_member] do
            {~p"/members/settings", "Discord authentication failed. Please try again."}
          else
            {~p"/members/login", "Discord login failed. Please try again."}
          end

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_location)
    end
  end

  def callback(conn, %{"provider" => "google", "error" => _error}) do
    # Different error handling based on whether user is authenticated
    {redirect_location, error_message} =
      if conn.assigns[:current_member] do
        {~p"/members/settings", "Google authentication was cancelled or failed."}
      else
        {~p"/members/login", "Google login was cancelled or failed."}
      end

    conn
    |> put_flash(:error, error_message)
    |> redirect(to: redirect_location)
  end

  def callback(conn, %{"provider" => "google"} = params) do
    session_params = get_session(conn, :oauth_session_params) || %{}
    conn = delete_session(conn, :oauth_session_params)

    google_config()
    |> Keyword.put(:session_params, session_params)
    |> Google.callback(params)
    |> case do
      {:ok, info} ->
        # Check if user is authenticated to determine behavior
        if conn.assigns[:current_member] do
          handle_google_linking(conn, info)
        else
          handle_google_login(conn, info)
        end

      {:error, _error} ->
        # Different error handling based on whether user is authenticated
        {redirect_location, error_message} =
          if conn.assigns[:current_member] do
            {~p"/members/settings", "Google authentication failed. Please try again."}
          else
            {~p"/members/login", "Google login failed. Please try again."}
          end

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_location)
    end
  end

  defp handle_google_linking(conn, %{user: user_info}) do
    email = user_info["email"] || ""

    if !IeeeTamuPortal.Members.valid_tamu_email?(email) do
      conn
      |> put_flash(:error, "You must use a Texas A&M Google account to link your account.")
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

    case Accounts.get_member_by_auth_sub(:discord, discord_sub) do
      nil ->
        conn
        |> put_flash(
          :error,
          "No account found linked to this Discord account. Please create an account first and link your Discord account in settings."
        )
        |> redirect(to: ~p"/members/login")

      member ->
        conn
        |> put_flash(:info, "Successfully logged in with Discord!")
        |> IeeeTamuPortalWeb.Auth.MemberAuth.log_in_member(member)
    end
  end

  defp handle_google_login(conn, %{user: user_info}) do
    email = user_info["email"] || ""

    if !IeeeTamuPortal.Members.valid_tamu_email?(email) do
      conn
      |> put_flash(:error, "You must use a Texas A&M Google account to log in.")
      |> redirect(to: ~p"/members/login")
    else
      google_sub = user_info["sub"]

      case Accounts.get_member_by_auth_sub(:google, google_sub) do
        nil ->
          # No existing member found, create a new one
          case create_member_from_google(user_info) do
            {:ok, member} ->
              conn
              |> put_flash(
                :info,
                "Welcome! Your account has been automatically created and you are now logged in."
              )
              |> IeeeTamuPortalWeb.Auth.MemberAuth.log_in_member(member)

            {:error, :already_exists} ->
              conn
              |> put_flash(
                :error,
                "Failed to create account - an account with that email already exists but is not linked to this google account."
              )
              |> redirect(to: ~p"/members/login")

            {:error, _changeset} ->
              conn
              |> put_flash(
                :error,
                "Failed to create account. Please try again or register manually."
              )
              |> redirect(to: ~p"/members/login")
          end

        member ->
          conn
          |> put_flash(:info, "Successfully logged in with Google!")
          |> IeeeTamuPortalWeb.Auth.MemberAuth.log_in_member(member)
      end
    end
  end

  defp create_member_from_google(user_info) do
    alias IeeeTamuPortal.Repo
    alias IeeeTamuPortal.Accounts.Member

    email = user_info["email"]
    google_sub = user_info["sub"]

    # Generate a secure random password (user won't need it since they'll use Google OAuth)
    random_password = :crypto.strong_rand_bytes(32) |> Base.encode64()

    Ecto.Multi.new()
    |> Ecto.Multi.run(:member, fn _repo, _changes ->
      Accounts.register_member(%{
        email: email,
        password: random_password
      })
    end)
    |> Ecto.Multi.run(:confirmed_member, fn _repo, %{member: member} ->
      confirmed_member =
        member
        |> Member.confirm_changeset()
        |> Repo.update()

      case confirmed_member do
        {:ok, member} -> {:ok, member}
        error -> error
      end
    end)
    |> Ecto.Multi.run(:auth_method, fn _repo, %{confirmed_member: member} ->
      Accounts.link_auth_method(member, %{
        provider: :google,
        sub: google_sub,
        email: email,
        email_verified: user_info["email_verified"] || true
      })
    end)
    |> Repo.transaction()
    |> case do
      # created new member
      {:ok, %{confirmed_member: member}} -> {:ok, member}
      # member already exists
      {:error, :member, _changeset, _changes_so_far} -> {:error, :already_exists}
      # other error
      {:error, _failed_operation, changeset, _changes_so_far} -> {:error, changeset}
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
