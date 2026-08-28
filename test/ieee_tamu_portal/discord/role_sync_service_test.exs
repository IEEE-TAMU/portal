defmodule IeeeTamuPortal.Discord.RoleSyncServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Discord.RoleSyncService

  @bot_url "http://discord-bot.test"

  setup do
    Application.put_env(:ieee_tamu_portal, :discord_bot_url, @bot_url)

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :discord_bot_req_opts,
      plug: {Req.Test, IeeeTamuPortal.Discord.Client},
      retry: false
    )

    on_exit(fn ->
      Logger.configure(level: :warning)
      Application.delete_env(:ieee_tamu_portal, :discord_bot_url)
      Application.delete_env(:ieee_tamu_portal, :discord_bot_req_opts)
    end)

    # The service logs at :info, which the test env suppresses.
    Logger.configure(level: :info)

    start_supervised!(RoleSyncService)

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

  describe "force_sync_all/0" do
    test "syncs all members with Discord accounts" do
      member_with_discord("discord-user-1")
      stub_roles_not_found()

      assert {:ok, summary} = RoleSyncService.force_sync_all()
      assert summary.total == 1
      assert summary.no_change == 1
    end
  end

  describe "sync_member/1 (cast)" do
    test "handles a member without a Discord account" do
      member = confirmed_member_fixture()

      capture_log(fn ->
        RoleSyncService.sync_member(member)
        sync_barrier()
      end)

      assert Process.whereis(RoleSyncService)
    end

    test "handles a member who left the guild" do
      member = member_with_discord()
      stub_roles_not_found()

      capture_log(fn ->
        RoleSyncService.sync_member(member)
        sync_barrier()
      end)

      assert Process.whereis(RoleSyncService)
    end
  end

  describe "handle_info :sync_all_roles" do
    test "runs the periodic sync" do
      member_with_discord()
      stub_roles_not_found()

      log =
        capture_log(fn ->
          send(RoleSyncService, :sync_all_roles)
          sync_barrier()
        end)

      assert Process.whereis(RoleSyncService)
      assert log =~ "Running periodic Discord role synchronization"
      assert log =~ "Periodic Discord role sync completed successfully"
    end
  end

  # sys messages are handled in mailbox order, so a get_state after a cast or
  # info message only returns once that message has been processed — a
  # deterministic sync point that does not run business logic.
  defp sync_barrier do
    :sys.get_state(RoleSyncService)
  end
end
