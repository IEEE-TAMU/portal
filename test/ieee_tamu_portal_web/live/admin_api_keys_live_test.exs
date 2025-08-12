defmodule IeeeTamuPortalWeb.AdminApiKeysLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.ApiFixtures
  import IeeeTamuPortalWeb.TestHelpers.AdminAuth, only: [admin_auth_conn: 1]

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Api.ApiKey

  setup do
    # Ensure clean slate for API keys
    Repo.delete_all(ApiKey)
    :ok
  end

  describe "Admin API Keys page" do
    test "renders with proper authentication", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/api-keys")

      assert html =~ "API Keys"
      assert html =~ "Create API Key"
    end

    test "returns 401 if admin is not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/admin/api-keys")
      assert conn.status == 401
    end

    test "shows empty state when no API keys exist", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/api-keys")

      assert html =~ "No API keys"
      assert html =~ "Get started by creating your first API key."
    end
  end

  describe "create API key" do
    test "validates and creates an API key, shows token banner", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/api-keys")

      # Open the create form (header button)
      _ =
        lv
        |> element("div.sm\\:flex-none button", "Create API Key")
        |> render_click()

      # Validate with empty name
      result =
        lv
        |> element("form")
        |> render_change(%{"api_key" => %{"name" => ""}})

      assert result =~ "can&#39;t be blank"

      # Submit valid form
      name = "Service #{System.unique_integer()}"

      result =
        lv
        |> form("form", %{"api_key" => %{"name" => name}})
        |> render_submit()

      # Shows success flash and token banner (token starts with portal_api_)
      assert result =~ "API key created successfully!"
      assert result =~ "API Key Created Successfully!"
      assert result =~ "portal_api_"

      # Newly created key appears in the table and is Active
      assert result =~ name
      assert result =~ "Active"
    end
  end

  describe "toggle active/inactive" do
    test "deactivates and reactivates an API key", %{conn: conn} do
      {_token, api_key} = admin_api_key_fixture(%{"name" => "To Toggle"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/api-keys")

      # Initially Active
      page = render(lv)
      assert page =~ api_key.name
      assert page =~ "Active"

      # Deactivate
      result =
        lv
        |> element("button", "Deactivate")
        |> render_click()

      assert result =~ "API key updated successfully!"
      assert result =~ "Inactive"

      # Activate again
      result =
        lv
        |> element("button", "Activate")
        |> render_click()

      assert result =~ "API key updated successfully!"
      assert result =~ "Active"
    end
  end

  describe "delete API key" do
    test "deletes an API key and shows empty state when last one removed", %{conn: conn} do
      {_token, api_key} = admin_api_key_fixture(%{"name" => "To Delete"})

      {:ok, lv, _html} =
        conn
        |> admin_auth_conn()
        |> live(~p"/admin/api-keys")

      # Delete
      result =
        lv
        |> element("button", "Delete")
        |> render_click()

      assert result =~ "API key deleted successfully!"
      refute result =~ api_key.name

      # With no API keys left, empty state is shown
      assert result =~ "No API keys"
    end
  end
end
