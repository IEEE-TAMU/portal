defmodule IeeeTamuPortal.Mautic.SyncServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Mautic.SyncService

  setup do
    # Mautic is not configured in the test env, so the service is started in
    # a state where every sync attempt fails — exactly the condition that
    # used to crash it repeatedly in production.
    start_supervised!(SyncService)

    :ok
  end

  describe "handle_cast :sync_member" do
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
  end

  describe "handle_call :force_sync" do
    test "contains a full sync crash when Mautic is unconfigured" do
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

  # GenServer processes its mailbox in order, so a call made after the casts
  # only runs once every cast has been handled — a deterministic sync point
  # for asserting on the cast results.
  defp sync_barrier do
    GenServer.call(SyncService, :force_sync, 5_000)
  end

  defp with_info(member) do
    {:ok, _info} =
      Members.create_member_info(member, %{
        first_name: "Test",
        last_name: "User",
        uin: 123_004_567,
        tshirt_size: :M,
        major: :CSCE,
        graduation_year: 2026,
        gender: :Male,
        international_student: false
      })

    member
  end
end
