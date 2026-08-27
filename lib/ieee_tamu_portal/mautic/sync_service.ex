defmodule IeeeTamuPortal.Mautic.SyncService do
  @moduledoc """
  GenServer that periodically syncs portal members to Mautic contacts.

  Runs a full sync every 24 hours and accepts cast messages for
  per-member syncs triggered by join/registration events.
  """

  use GenServer

  alias IeeeTamuPortal.Mautic.ContactSync

  require Logger

  # Run every 24 hours (in milliseconds)
  @daily_interval 24 * 60 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if configured?() do
      Logger.info("Starting Mautic SyncService GenServer")
      schedule_next_sync()
    else
      Logger.warning("Mautic not configured — SyncService started in idle mode")
    end

    {:ok, %{configured: configured?()}}
  end

  # Public API

  @doc """
  Forces an immediate full sync of all members to Mautic.
  """
  def force_sync do
    if configured?() do
      GenServer.call(__MODULE__, :force_sync, 120_000)
    else
      {:error, :not_configured}
    end
  end

  @doc """
  Queues a per-member sync to Mautic.

  Called when a member confirms their email, submits info,
  or completes annual registration. No-ops gracefully if
  Mautic is not configured (e.g., in test/dev).
  """
  def sync_member(member) do
    if configured?() do
      GenServer.cast(__MODULE__, {:sync_member, member})
    end
  end

  defp configured? do
    IeeeTamuPortal.Features.enabled?(:mautic)
  end

  @impl true
  def handle_info(:sync_all, state) do
    Logger.info("Running periodic Mautic contact sync")

    case safe_sync_all() do
      {:ok, summary} ->
        Logger.info("Periodic Mautic sync completed: #{inspect(summary)}")

      {:error, reason} ->
        Logger.error("Periodic Mautic sync failed: #{inspect(reason)}")
    end

    schedule_next_sync()
    {:noreply, state}
  end

  @impl true
  def handle_call(:force_sync, _from, state) do
    Logger.info("Force running Mautic contact sync")

    result = safe_sync_all()

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:sync_member, member_or_id}, state) do
    # ContactSync accepts either a member id or a %Member{} struct; callers
    # (e.g. payment events) cast bare ids, so never assume a struct here.
    case safe_sync(member_or_id) do
      {:ok, action} ->
        Logger.debug("Mautic sync for #{inspect(member_or_id)}: #{inspect(action)}")

      {:error, reason} ->
        Logger.warning("Mautic sync failed for #{inspect(member_or_id)}: #{reason}")
    end

    {:noreply, state}
  end

  # A crash inside a cast handler would kill this GenServer and drop every
  # sync queued behind the failing one, so exceptions are contained here and
  # logged instead.
  defp safe_sync(member_or_id) do
    ContactSync.sync_member(member_or_id)
  rescue
    exception ->
      Logger.error(
        "Mautic sync crashed for #{inspect(member_or_id)}: #{Exception.message(exception)}"
      )

      {:error, "crashed: #{Exception.message(exception)}"}
  end

  # Same containment for the full sync: a transient DB failure must not take
  # down the service (sync_all_members signals failure by raising).
  defp safe_sync_all do
    ContactSync.sync_all_members()
  rescue
    exception ->
      Logger.error("Mautic full sync crashed: #{Exception.message(exception)}")
      {:error, "crashed: #{Exception.message(exception)}"}
  end

  # Private functions

  defp schedule_next_sync do
    Process.send_after(self(), :sync_all, @daily_interval)
  end
end
