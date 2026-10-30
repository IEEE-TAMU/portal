defmodule IeeeTamuPortal.Github.TeamSyncService do
  @moduledoc """
  Periodically synchronizes GitHub organization team membership.
  """

  use GenServer

  require Logger

  alias IeeeTamuPortal.Github.TeamManager

  @sync_interval 6 * 60 * 60 * 1000

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Forces an immediate full synchronization.
  """
  def force_sync_all do
    GenServer.call(__MODULE__, :force_sync_all, 30_000)
  end

  @doc """
  Queues a synchronization for a single member.
  """
  def sync_member(member) do
    GenServer.cast(__MODULE__, {:sync_member, member})
  end

  @impl true
  def init(_opts) do
    schedule_sync()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_all_teams, state) do
    Logger.info("Running periodic GitHub team synchronization")
    run_sync()
    schedule_sync()
    {:noreply, state}
  end

  @impl true
  def handle_call(:force_sync_all, _from, state) do
    {:reply, run_sync(), state}
  end

  @impl true
  def handle_cast({:sync_member, member}, state) do
    case TeamManager.sync_member_teams(member) do
      {:ok, _actions} ->
        :ok

      {:error, reason} ->
        Logger.warning("GitHub team sync failed for member #{member.id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp run_sync do
    {:ok, summary} = TeamManager.sync_all_github_members()
    Logger.info("Periodic GitHub team sync completed successfully: #{inspect(summary)}")
    {:ok, summary}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_all_teams, @sync_interval)
  end
end
