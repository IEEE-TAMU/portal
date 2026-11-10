defmodule IeeeTamuPortalWeb.AdminOidcClientsLiveTest do
  use IeeeTamuPortalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.OIDCFixtures

  import IeeeTamuPortalWeb.TestHelpers.AdminAuth,
    only: [admin_auth_conn: 1, officer_auth_conn: 1]

  alias IeeeTamuPortal.OIDC.Client
  alias IeeeTamuPortal.OIDC.Clients
  alias IeeeTamuPortal.Repo

  setup do
    Repo.delete_all(Client)
    :ok
  end

  describe "access control" do
    test "redirects unauthenticated visitors to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/oidc-clients")
      assert redirected_to(conn) == ~p"/members/login"
    end

    test "redirects officers who are not admins", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin"}}} =
               conn
               |> officer_auth_conn()
               |> live(~p"/admin/oidc-clients")
    end
  end

  describe "listing" do
    test "renders existing clients", %{conn: conn} do
      {client, _secret} = oidc_client_fixture()

      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      assert html =~ "OIDC Clients"
      assert html =~ client.name
      assert html =~ client.client_id
      assert html =~ "Never"
      assert html =~ "Active"
    end

    test "shows the empty state when no clients exist", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      assert html =~ "No OIDC clients"
    end
  end

  describe "create" do
    test "creates a client and shows the secret once", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      lv |> element("#new-oidc-client") |> render_click()

      client_id = "lounge-#{System.unique_integer([:positive])}"

      html =
        lv
        |> form("#oidc_client_form", %{
          "client" => %{
            "name" => "IEEE TAMU Lounge",
            "client_id" => client_id,
            "redirect_uris" => "https://lounge.ieeetamu.org/api/auth/callback",
            "scopes" => "openid profile email role",
            "enabled" => "true"
          }
        })
        |> render_submit()

      assert html =~ "OIDC client created successfully!"
      assert html =~ "OIDC Client Secret Created Successfully!"
      assert html =~ client_id
      assert html =~ "oidc_secret_"

      client = Clients.get_by_client_id(client_id)
      assert client
      assert Clients.authenticate(client, extract_secret(html))

      html = lv |> element("button", "Dismiss") |> render_click()
      refute html =~ "oidc_secret_"
    end

    test "validates redirect URIs", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      lv |> element("#new-oidc-client") |> render_click()

      html =
        lv
        |> form("#oidc_client_form", %{
          "client" => %{
            "name" => "Bad Client",
            "client_id" => "bad-client",
            "redirect_uris" => "http://example.com/callback",
            "scopes" => "openid",
            "enabled" => "true"
          }
        })
        |> render_submit()

      assert html =~ "contains invalid URIs"
    end
  end

  describe "update" do
    test "edits a client", %{conn: conn} do
      {client, _secret} = oidc_client_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      lv
      |> element("button[phx-click=edit][phx-value-id='#{client.id}']")
      |> render_click()

      html =
        lv
        |> form("#oidc_client_form", %{
          "client" => %{
            "name" => "Renamed Client",
            "redirect_uris" => "https://new.example/callback",
            "scopes" => "openid profile",
            "enabled" => "true"
          }
        })
        |> render_submit()

      assert html =~ "OIDC client updated successfully!"

      updated = Clients.get_by_client_id(client.client_id)
      assert updated.name == "Renamed Client"
      assert Clients.redirect_uris(updated) == ["https://new.example/callback"]
      assert Clients.scopes(updated) == ["openid", "profile"]
    end

    test "disables and enables a client", %{conn: conn} do
      {client, _secret} = oidc_client_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      html =
        lv
        |> element("button[phx-click=toggle_enabled][phx-value-id='#{client.id}']")
        |> render_click()

      assert html =~ "Disabled"
      refute Clients.get_by_client_id(client.client_id).enabled

      html =
        lv
        |> element("button[phx-click=toggle_enabled][phx-value-id='#{client.id}']")
        |> render_click()

      assert html =~ "Active"
      assert Clients.get_by_client_id(client.client_id).enabled
    end

    test "rotates the client secret", %{conn: conn} do
      {client, old_secret} = oidc_client_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      html =
        lv
        |> element("button[phx-click=rotate_secret][phx-value-id='#{client.id}']")
        |> render_click()

      assert html =~ "Client secret rotated successfully!"
      assert html =~ "oidc_secret_"

      new_secret = extract_secret(html)
      updated = Clients.get_by_client_id(client.client_id)

      refute Clients.authenticate(updated, old_secret)
      assert Clients.authenticate(updated, new_secret)
    end

    test "deletes a client", %{conn: conn} do
      {client, _secret} = oidc_client_fixture()

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/oidc-clients")

      html =
        lv
        |> element("button[phx-click=delete][phx-value-id='#{client.id}']")
        |> render_click()

      assert html =~ "OIDC client deleted successfully!"
      refute Clients.get_by_client_id(client.client_id)
      assert html =~ "No OIDC clients"
    end
  end

  defp extract_secret(html) do
    [_, secret] = Regex.run(~r/(oidc_secret_[A-Za-z0-9_-]+)/, html)
    secret
  end
end
