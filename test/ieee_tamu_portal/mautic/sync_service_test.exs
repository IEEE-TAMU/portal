defmodule IeeeTamuPortal.Mautic.SyncServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Mautic.SyncService

  describe "when Mautic is not configured" do
    setup do
      # Mautic is not configured in the test env, so the service is started in
      # a state where every sync attempt fails — exactly the condition that
      # used to crash it repeatedly in production.
      start_supervised!(SyncService)

      :ok
    end

    test "handles a bare member id (as cast by payment events)" do
      log =
        capture_log(fn ->
          GenServer.cast(SyncService, {:sync_member, 0})
          sync_barrier()
        end)

      assert Process.whereis(SyncService)
      refute log =~ "Mautic sync crashed"
    end

    test "survives a member sync crash when Mautic is unconfigured" do
      member = member_fixture() |> with_info()

      log =
        capture_log(fn ->
          GenServer.cast(SyncService, {:sync_member, member.id})
          GenServer.cast(SyncService, {:sync_member, member})
          sync_barrier()
        end)

      assert Process.whereis(SyncService)
      assert log =~ "Mautic sync crashed"
      assert log =~ "Mautic configuration not found"
    end

    test "does not leak credentials in crash logs" do
      member = member_fixture() |> with_info()

      log =
        capture_log(fn ->
          GenServer.cast(SyncService, {:sync_member, member})
          sync_barrier()
        end)

      refute log =~ "ieee-portal"
    end

    test "contains a full sync crash" do
      member_fixture() |> with_info()

      log =
        capture_log(fn ->
          result = GenServer.call(SyncService, :force_sync, 5_000)

          assert {:error, "crashed: " <> _reason} = result
        end)

      assert Process.whereis(SyncService)
      assert log =~ "Mautic full sync crashed"
    end

    test "completes a full sync when there is nothing to sync" do
      result = GenServer.call(SyncService, :force_sync, 5_000)

      assert {:ok, %{success: 0, errors: 0}} = result
    end
  end

  describe "when Mautic is configured" do
    @password "super-secret-password"

    setup do
      Application.put_env(:ieee_tamu_portal, :mautic,
        base_url: "http://mautic.test",
        username: "ieee-portal",
        password: @password
      )

      Req.Test.set_req_test_to_shared()

      Application.put_env(:ieee_tamu_portal, :mautic_req_opts,
        plug: {Req.Test, IeeeTamuPortal.Mautic.Client},
        retry: false
      )

      on_exit(fn ->
        Logger.configure(level: :warning)
        Application.delete_env(:ieee_tamu_portal, :mautic)
        Application.delete_env(:ieee_tamu_portal, :mautic_req_opts)
      end)

      Logger.configure(level: :info)

      start_supervised!(SyncService)

      :ok
    end

    test "syncs a cast member to Mautic" do
      member = member_fixture() |> with_info()

      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        Req.Test.json(conn, %{"contacts" => %{"1" => %{"id" => 1}}})
      end)

      log =
        capture_log(fn ->
          GenServer.cast(SyncService, {:sync_member, member.id})
          sync_barrier()
        end)

      assert Process.whereis(SyncService)
      assert log =~ "Mautic sync success for member #{member.id}"
      assert log =~ member.email
      refute log =~ @password
    end

    test "reports HTTP failures without crashing" do
      member = member_fixture() |> with_info()

      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "nope"}))
      end)

      log =
        capture_log(fn ->
          GenServer.cast(SyncService, {:sync_member, member.id})
          sync_barrier()
        end)

      assert Process.whereis(SyncService)
      assert log =~ "Mautic sync failed for #{member.id}: HTTP 500"
    end

    test "force_sync/0 uploads all members with info" do
      member_fixture() |> with_info()
      member_fixture() |> with_info()

      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        Req.Test.json(conn, %{"contacts" => %{}})
      end)

      assert {:ok, %{success: 2, errors: 0}} = SyncService.force_sync()
      assert Process.whereis(SyncService)
    end

    test "runs the periodic full sync" do
      member_fixture() |> with_info()

      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        Req.Test.json(conn, %{"contacts" => %{}})
      end)

      log =
        capture_log(fn ->
          send(SyncService, :sync_all)
          sync_barrier()
        end)

      assert Process.whereis(SyncService)
      assert log =~ "Running periodic Mautic contact sync"
      assert log =~ "Periodic Mautic sync completed: %{success: 1, errors: 0}"
    end
  end

  # sys messages are handled in mailbox order, so a get_state after a cast or
  # info message only returns once that message has been processed — a
  # deterministic sync point that does not run business logic.
  defp sync_barrier do
    :sys.get_state(SyncService)
  end

  defp with_info(member) do
    # UINs are unique and must match ^\d{3}00\d{4}$
    uin =
      ("12300" <>
         (System.unique_integer([:positive])
          |> rem(10_000)
          |> Integer.to_string()
          |> String.pad_leading(4, "0")))
      |> String.to_integer()

    {:ok, _info} =
      Members.create_member_info(member, %{
        first_name: "Test",
        last_name: "User",
        uin: uin,
        tshirt_size: :M,
        major: :CSCE,
        graduation_year: 2026,
        gender: :Male,
        international_student: false
      })

    member
  end
end
