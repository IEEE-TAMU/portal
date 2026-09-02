defmodule IeeeTamuPortalWeb.OAuthControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Accounts.AuthMethod
  alias IeeeTamuPortal.Repo

  describe "GET /auth/:provider" do
    test "returns 404 for invalid provider", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/auth/invalid_provider")
      end
    end

    test "discord authorize redirects to discord", %{conn: conn} do
      conn = get(conn, ~p"/auth/discord")
      assert redirected_to(conn) =~ "discord"
    end

    test "google authorize redirects to google", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")
      assert redirected_to(conn) =~ "google"
    end
  end

  describe "GET /auth/:provider/callback" do
    test "discord callback with error redirects to login", %{conn: conn} do
      conn = get(conn, ~p"/auth/discord/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Discord login was cancelled or failed."
    end

    test "discord callback with error when logged in redirects to settings", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      conn = get(conn, ~p"/auth/discord/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Discord authentication was cancelled or failed."
    end

    test "google callback with error redirects to login", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Google login was cancelled or failed."
    end

    test "google callback with error when logged in redirects to settings", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      conn = get(conn, ~p"/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == ~p"/members/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Google authentication was cancelled or failed."
    end
  end

  describe "GET /auth/google/callback (success paths)" do
    # A fake Google OAuth adapter whose returned user info is controlled via
    # Application config so we can exercise the success path without network.
    defmodule FakeGoogleAdapter do
      def authorize_url(_config),
        do: {:ok, %{url: "https://accounts.google.com/fake", session_params: %{}}}

      def callback(_config, _params) do
        user =
          Application.get_env(:ieee_tamu_portal, FakeGoogleAdapter, [])[:user] ||
            %{"sub" => "google-sub", "email" => "member@tamu.edu", "email_verified" => true}

        {:ok, %{user: user}}
      end
    end

    setup do
      on_exit(fn ->
        Application.delete_env(:ieee_tamu_portal, IeeeTamuPortalWeb.OAuthController)
        Application.delete_env(:ieee_tamu_portal, FakeGoogleAdapter)
      end)

      :ok
    end

    defp with_google_user(user) do
      Application.put_env(:ieee_tamu_portal, IeeeTamuPortalWeb.OAuthController,
        google_adapter: FakeGoogleAdapter
      )

      Application.put_env(:ieee_tamu_portal, FakeGoogleAdapter, user: user)
    end

    test "links an existing email/password account, confirms it, and logs in", %{conn: conn} do
      member = member_fixture(%{email: "existing@tamu.edu"})
      refute member.confirmed_at

      with_google_user(%{
        "sub" => "google-sub-existing",
        "email" => "existing@tamu.edu",
        "email_verified" => true
      })

      conn = get(conn, ~p"/auth/google/callback?code=123")

      assert get_session(conn, :member_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully linked your Google account and signed in!"

      reloaded = Repo.get!(IeeeTamuPortal.Accounts.Member, member.id)
      assert reloaded.confirmed_at

      auth = Repo.get_by(AuthMethod, member_id: member.id, provider: :google)
      assert auth
      assert auth.sub == "google-sub-existing"
    end

    test "does not link when the Google email is unverified", %{conn: conn} do
      member = member_fixture(%{email: "unverified@tamu.edu"})
      refute member.confirmed_at

      with_google_user(%{
        "sub" => "google-sub-unverified",
        "email" => "unverified@tamu.edu",
        "email_verified" => false
      })

      conn = get(conn, ~p"/auth/google/callback?code=123")

      assert redirected_to(conn) == ~p"/members/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "couldn't verify your Google email address"

      reloaded = Repo.get!(IeeeTamuPortal.Accounts.Member, member.id)
      refute reloaded.confirmed_at
      refute Repo.get_by(AuthMethod, member_id: member.id, provider: :google)
    end

    test "creates a new account when no member exists for the email", %{conn: conn} do
      with_google_user(%{
        "sub" => "google-sub-new",
        "email" => "brandnew@tamu.edu",
        "email_verified" => true
      })

      conn = get(conn, ~p"/auth/google/callback?code=123")

      assert get_session(conn, :member_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "automatically created"

      member = Repo.get_by(IeeeTamuPortal.Accounts.Member, email: "brandnew@tamu.edu")
      assert member
      assert member.confirmed_at

      auth = Repo.get_by(AuthMethod, member_id: member.id, provider: :google)
      assert auth
      assert auth.sub == "google-sub-new"
    end

    test "logs in when the Google sub is already linked to a member", %{conn: conn} do
      member = confirmed_member_fixture(%{email: "linked@tamu.edu"})

      {:ok, _auth} =
        IeeeTamuPortal.Accounts.link_auth_method(member, %{
          provider: :google,
          sub: "google-sub-linked",
          email: "linked@tamu.edu",
          email_verified: true
        })

      with_google_user(%{
        "sub" => "google-sub-linked",
        "email" => "linked@tamu.edu",
        "email_verified" => true
      })

      conn = get(conn, ~p"/auth/google/callback?code=123")

      assert get_session(conn, :member_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully logged in with Google!"
    end
  end
end
