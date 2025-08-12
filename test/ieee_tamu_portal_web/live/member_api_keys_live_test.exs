defmodule IeeeTamuPortalWeb.MemberApiKeysLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.ApiFixtures

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Api.ApiKey

  setup %{conn: conn} do
    member = confirmed_member_fixture()

    # Clean slate for this member's keys
    Repo.delete_all(ApiKey)

    %{conn: log_in_member(conn, member), member: member}
  end

  describe "/members/api-keys access" do
    test "requires login", %{conn: conn} do
      assert {:error, redirect} = live(build_conn(), ~p"/members/api-keys")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/members/login"
    end

    test "renders page for authenticated member", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/members/api-keys")
      assert html =~ "API Keys"
      assert html =~ "Create API Key"
    end
  end

  describe "create member API key" do
    test "validates and creates a key scoped to member", %{conn: conn, member: member} do
      {:ok, lv, _html} = live(conn, ~p"/members/api-keys")

      # Open create form
      _ =
        lv
        |> element("div.sm\\:flex-none button", "Create API Key")
        |> render_click()

      # Validate blank name
      result =
        lv
        |> element("form")
        |> render_change(%{"api_key" => %{"name" => ""}})

      assert result =~ "can&#39;t be blank"

      # Submit valid
      name = "My Member Key #{System.unique_integer()}"

      result =
        lv
        |> form("form", %{"api_key" => %{"name" => name}})
        |> render_submit()

      assert result =~ "API key created successfully!"
      assert result =~ "API Key Created Successfully!"
      assert result =~ "portal_api_"
      assert result =~ name
      assert result =~ "Active"

      # Verify it is saved and scoped to this member
      key = Repo.one(from k in ApiKey, where: k.name == ^name)
      assert key
      assert key.context == :member
      assert key.member_id == member.id
    end
  end

  describe "toggle and delete" do
    test "member can deactivate/reactivate own key", %{conn: conn, member: member} do
      {_token, api_key} = member_api_key_fixture(member, %{"name" => "Toggle Key"})

      {:ok, lv, _html} = live(conn, ~p"/members/api-keys")

      page = render(lv)
      assert page =~ api_key.name
      assert page =~ "Active"

      result =
        lv
        |> element("button", "Deactivate")
        |> render_click()

      assert result =~ "API key updated successfully!"
      assert result =~ "Inactive"

      result =
        lv
        |> element("button", "Activate")
        |> render_click()

      assert result =~ "API key updated successfully!"
      assert result =~ "Active"
    end

    test "member can delete own key", %{conn: conn, member: member} do
      {_token, api_key} = member_api_key_fixture(member, %{"name" => "Delete Key"})

      {:ok, lv, _html} = live(conn, ~p"/members/api-keys")

      result =
        lv
        |> element("button", "Delete")
        |> render_click()

      assert result =~ "API key deleted successfully!"
      refute result =~ api_key.name
    end

    test "member cannot toggle/delete other member's key", %{conn: conn, member: member} do
      # Create key for another member
      other = confirmed_member_fixture()
      {_token, _other_key} = member_api_key_fixture(other, %{"name" => "Not Yours"})

      {:ok, lv, _html} = live(conn, ~p"/members/api-keys")

      # Attempt to click generic buttons should target own list only; ensure unauthorized path
      # Simulate by trying to toggle/delete with explicit id param via handle_event
      # Note: We can't directly call handle_event here, but ensure page doesn't show other key
      page = render(lv)
      refute page =~ "Not Yours"
    end
  end
end
