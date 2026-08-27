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

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :discord_bot_req_opts,
      plug: {Req.Test, IeeeTamuPortal.Discord.Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :discord_bot_url)
      Application.delete_env(:ieee_tamu_portal, :discord_bot_req_opts)
    end)

    :ok
  end

  defp member_with_discord(sub \\ "discord-user-1") do
    member = confirmed_member_fixture()

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
  end
end
