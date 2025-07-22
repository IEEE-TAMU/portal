defmodule IeeeTamuPortal.Members.AgeUpdater do
  @moduledoc """
  GenServer that runs daily to increment the age of member infos that haven't been updated in over a year.

  This service automatically updates member ages to keep them current, assuming that if a member
  info hasn't been updated in over a year, their age should be incremented by 1.
  """

  use GenServer

  alias IeeeTamuPortal.Repo
  alias IeeeTamuPortal.Members.Info

  import Ecto.Query

  require Logger

  # Run every 24 hours (in milliseconds)
  @daily_interval 24 * 60 * 60 * 1000

  # For testing purposes, you can use a shorter interval
  # @daily_interval 60 * 1000  # 1 minute for testing

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting AgeUpdater GenServer")

    # Schedule the first run
    schedule_next_run()

    {:ok, %{}}
  end

  # Public API

  @doc """
  Forces an immediate age update run.
  Returns {:ok, count} where count is the number of records updated, or {:error, reason}.
  """
  def force_update do
    GenServer.call(__MODULE__, :force_update)
  end

  @impl true
  def handle_info(:update_ages, state) do
    Logger.info("Running daily age update task")

    count = update_stale_ages()
    Logger.info("Daily age update completed successfully - updated #{count} member infos")

    # Schedule the next run
    schedule_next_run()

    {:noreply, state}
  end

  @impl true
  def handle_call(:force_update, _from, state) do
    Logger.info("Force running age update task")

    count = update_stale_ages()
    result = {:ok, count}

    {:reply, result, state}
  end

  # Private functions

  defp schedule_next_run do
    Process.send_after(self(), :update_ages, @daily_interval)
  end

  defp update_stale_ages do
    # complete correctness really doesn't matter here, just need to update ages
    one_year_ago = DateTime.utc_now() |> DateTime.add(-365, :day)

    # Get all member infos that haven't been updated in over a year and have an age
    query =
      from i in Info,
        where: i.updated_at < ^one_year_ago,
        where: not is_nil(i.age),
        select: i

    member_infos = Repo.all(query)

    Logger.info("Found #{length(member_infos)} member infos to update")

    # Update each member info by incrementing age
    # Let it fail if any individual update fails
    Enum.each(member_infos, fn info ->
      info
      |> Info.changeset(%{age: info.age + 1})
      |> Repo.update!()
    end)

    length(member_infos)
  end
end
