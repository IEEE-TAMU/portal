defmodule IeeeTamuPortalWeb.OAuthController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Accounts
  alias Assent.Strategy.Discord

  @doc """
  Initiates Discord OAuth flow
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
        conn
        |> put_flash(:error, "Failed to initiate Discord authentication. Please try again.")
        |> redirect(to: ~p"/members/settings")
    end
  end

  @doc """
  Handles OAuth callback from Discord
  """

  def callback(conn, %{"provider" => "discord", "error" => _error}) do
    conn
    |> put_flash(:error, "Discord authentication was cancelled or failed.")
    |> redirect(to: ~p"/members/settings")
  end

  def callback(conn, %{"provider" => "discord"} = params) do
    session_params = get_session(conn, :oauth_session_params) || %{}
    conn = delete_session(conn, :oauth_session_params)

    discord_config()
    |> Keyword.put(:session_params, session_params)
    |> Discord.callback(params)
    |> case do
      {:ok, user_info} ->
        handle_successful_auth(conn, user_info, :discord)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Discord authentication failed. Please try again.")
        |> redirect(to: ~p"/members/settings")
    end
  end

  defp handle_successful_auth(conn, %{user: user_info}, provider) do
    current_member = conn.assigns.current_member

    member_auth_attrs =
      Map.take(user_info, ~w[sub preferred_username email email_verified])
      |> Map.put("provider", provider)

    case Accounts.link_auth_method(current_member, member_auth_attrs) do
      {:ok, _auth_method} ->
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

  defp discord_config do
    config = Application.get_env(:ieee_tamu_portal, :discord_oauth)

    [
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri]
      # authorization_params: [scope: "identify"] # do not need email scope for linking
    ]
  end
end
