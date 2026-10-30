defmodule IeeeTamuPortal.Discord.RoleManagerTest do
  use IeeeTamuPortal.DataCase, async: false

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Discord.RoleManager

  @bot_url "http://discord-bot.test"

  setup do
    registration_year_setting_fixture("2026")

    Application.put_env(:ieee_tamu_portal, :discord_bot_url, @bot_url)
    Application.put_env(:ieee_tamu_portal, :discord_officer_role, "Officer")

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :discord_bot_req_opts,
      plug: {Req.Test, IeeeTamuPortal.Discord.Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :discord_bot_url)
      Application.delete_env(:ieee_tamu_portal, :discord_bot_req_opts)
      Application.delete_env(:ieee_tamu_portal, :discord_officer_role)
    end)

    :ok
  end

  defp member_with_discord(sub \\ "discord-user-1") do
    confirmed_member_fixture()
    |> link_discord(sub)
  end

  defp privileged_with_discord(role, sub \\ "discord-user-1") do
    member = member_with_discord(sub)
    {:ok, member} = Accounts.update_member_role(member, role)
    member
  end

  defp link_discord(member, sub) do
    {:ok, _auth} =
      Accounts.link_auth_method(member, %{
        provider: :discord,
        sub: sub,
        email: member.email,
        email_verified: true
      })

    member
  end

  defp stub_roles_not_found do
    Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(404, Jason.encode!(%{"message" => "User not found in guild"}))
    end)
  end

  defp stub_roles(roles) do
    Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
      Req.Test.json(conn, %{"success" => true, "roles" => roles})
    end)
  end

  describe "sync_member_roles/1" do
    test "returns {:ok, :no_discord_account} when no Discord account is linked" do
      member = confirmed_member_fixture()

      assert {:ok, :no_discord_account} = RoleManager.sync_member_roles(member)
    end

    test "treats a member who left the guild as synced, not errored" do
      member = member_with_discord()
      stub_roles_not_found()

      assert {:ok, %{member_role: :not_in_guild}} = RoleManager.sync_member_roles(member)
    end

    test "adds the Member role for a paid member without it" do
      member = member_with_discord() |> paid()
      stub_roles([])
      stub_role_change()

      assert {:ok, %{member_role: :role_added}} = RoleManager.sync_member_roles(member)
    end

    test "removes the Member role from an unpaid member that has it" do
      member = member_with_discord()
      stub_roles([%{"name" => "Member"}])
      stub_role_change()

      assert {:ok, %{member_role: :role_removed}} = RoleManager.sync_member_roles(member)
    end

    test "returns an error when adding the role fails" do
      member = member_with_discord() |> paid()
      stub_roles([])

      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"message" => "boom"}))
      end)

      assert {:error, "Failed to add role: 500"} = RoleManager.sync_member_roles(member)
    end

    test "adds the Officer role for an officer without it" do
      member = privileged_with_discord(:officer)
      stub_roles([])
      stub_role_change()

      assert {:ok, %{member_role: :no_change_needed, officer_role: :role_added}} =
               RoleManager.sync_member_roles(member)
    end

    test "adds the Officer role for an admin without it" do
      member = privileged_with_discord(:admin)
      stub_roles([])
      stub_role_change()

      assert {:ok, %{member_role: :no_change_needed, officer_role: :role_added}} =
               RoleManager.sync_member_roles(member)
    end

    test "removes the Officer role after the portal role is revoked" do
      member = member_with_discord()
      stub_roles([%{"name" => "Officer"}])
      stub_role_change()

      assert {:ok, %{member_role: :no_change_needed, officer_role: :role_removed}} =
               RoleManager.sync_member_roles(member)
    end

    test "reconciles Member and Officer roles from a single role lookup" do
      member = privileged_with_discord(:officer) |> paid()
      stub_roles([])
      stub_role_change()
      stub_role_change()

      assert {:ok, %{member_role: :role_added, officer_role: :role_added}} =
               RoleManager.sync_member_roles(member)
    end
  end

  describe "role policy" do
    test "should_have_officer_role?/1 treats officers and admins as officers" do
      assert RoleManager.should_have_officer_role?(%Accounts.Member{role: :officer})
      assert RoleManager.should_have_officer_role?(%Accounts.Member{role: :admin})
      refute RoleManager.should_have_officer_role?(%Accounts.Member{role: :member})
    end

    test "officer_role_name/0 defaults to Officer" do
      Application.delete_env(:ieee_tamu_portal, :discord_officer_role)
      assert RoleManager.officer_role_name() == "Officer"
    end

    test "officer_role_name/0 uses the configured role name" do
      Application.put_env(:ieee_tamu_portal, :discord_officer_role, "Leadership")
      assert RoleManager.officer_role_name() == "Leadership"
    end
  end

  describe "remove_managed_roles/1" do
    test "removes both Member and Officer roles" do
      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        Req.Test.json(conn, %{"success" => true})
      end)

      Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
        Req.Test.json(conn, %{"success" => true})
      end)

      assert :ok = RoleManager.remove_managed_roles("discord-user-1")
    end
  end

  describe "sync_all_discord_members/0" do
    test "counts members not in the guild as no_change instead of errors" do
      member_with_discord("discord-user-1")
      member_with_discord("discord-user-2")

      # One member with a Discord account that is in the guild and needs no change
      stub_roles_not_found()
      stub_roles_not_found()

      assert {:ok, summary} = RoleManager.sync_all_discord_members()

      assert summary.total == 2
      assert summary.no_change == 2
      assert summary.errors == 0
    end

    test "counts added and removed roles in the summary" do
      member_with_discord("discord-user-1") |> paid()
      member_with_discord("discord-user-2")

      stub_roles([])
      stub_role_change()
      stub_roles([%{"name" => "Member"}])
      stub_role_change()

      assert {:ok, summary} = RoleManager.sync_all_discord_members()

      assert summary.roles_added == 1
      assert summary.roles_removed == 1
      assert summary.errors == 0
    end

    test "counts Officer role changes in the summary" do
      privileged_with_discord(:officer, "discord-user-1")

      stub_roles([])
      stub_role_change()

      assert {:ok, summary} = RoleManager.sync_all_discord_members()

      assert summary.total == 1
      assert summary.roles_added == 1
      assert summary.errors == 0
    end
  end

  defp paid(member) do
    {:ok, registration} = IeeeTamuPortal.Members.get_or_create_registration(member, 2026)
    {:ok, _} = IeeeTamuPortal.Members.update_registration(registration, %{payment_override: true})
    member
  end

  defp stub_role_change do
    Req.Test.expect(IeeeTamuPortal.Discord.Client, fn conn ->
      Req.Test.json(conn, %{"success" => true})
    end)
  end
end
