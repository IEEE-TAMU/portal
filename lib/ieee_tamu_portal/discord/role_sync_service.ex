defmodule IeeeTamuPortal.Discord.RoleSyncService do
  @moduledoc """
  GenServer that periodically synchronizes Discord roles for all members.

  This service runs periodically to ensure Discord roles are kept in sync with
  member authentication and payment status. It also provides an interface for
  immediate synchronization when triggered by events.
  """

  use GenServer

  alias IeeeTamuPortal.Discord.RoleManager

  require Logger

  # Run every 6 hours (in milliseconds)
  @sync_interval 6 * 60 * 60 * 1000

  # For testing purposes, you can use a shorter interval
  # @sync_interval 5 * 60 * 1000  # 5 minutes for testing

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Discord RoleSyncService GenServer")

    # Schedule the first run
    schedule_next_sync()

    {:ok, %{}}
  end

  # Public API

  @doc """
  Forces an immediate role synchronization for all Discord members.
  Returns {:ok, summary} where summary contains sync statistics.
  """
  def force_sync_all do
    # 30 second timeout
    GenServer.call(__MODULE__, :force_sync_all, 30_000)
  end

  @doc """
  Synchronizes roles for a specific member.
  This is called when member status changes (payment, Discord linking, etc.).
  """
  def sync_member(member) do
    GenServer.cast(__MODULE__, {:sync_member, member})
  end

  @impl true
  def handle_info(:sync_all_roles, state) do
    Logger.info("Running periodic Discord role synchronization")

    case RoleManager.sync_all_discord_members() do
      {:ok, summary} ->
        Logger.info("Periodic Discord role sync completed successfully: #{inspect(summary)}")
    end

    # Schedule the next run
    schedule_next_sync()

    {:noreply, state}
  end

  @impl true
  def handle_call(:force_sync_all, _from, state) do
    Logger.info("Force running Discord role synchronization")

    result = RoleManager.sync_all_discord_members()

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:sync_member, member}, state) do
    Logger.debug("Synchronizing Discord roles for member #{member.id}")

    case RoleManager.sync_member_roles(member) do
      {:ok, action} ->
        Logger.debug("Discord role sync for member #{member.id}: #{inspect(action)}")

      {:error, reason} ->
        Logger.warning("Failed to sync Discord roles for member #{member.id}: #{reason}")
    end

    {:noreply, state}
  end

  # Private functions

  defp schedule_next_sync do
    Process.send_after(self(), :sync_all_roles, @sync_interval)
  end
end
