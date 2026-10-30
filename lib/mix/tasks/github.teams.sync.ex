defmodule Mix.Tasks.Github.Teams.Sync do
  use Mix.Task

  @shortdoc "Synchronizes GitHub organization team membership"
  @moduledoc """
  Runs a full GitHub team synchronization immediately.

      mix github.teams.sync

  This is useful for the initial backfill after configuring the GitHub App,
  or to retry after GitHub API errors.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, summary} = IeeeTamuPortal.Github.TeamManager.sync_all_github_members()

    Mix.shell().info("""
    GitHub team synchronization complete:
      total:            #{summary.total}
      members added:    #{summary.members_added}
      members removed:  #{summary.members_removed}
      officers added:   #{summary.officers_added}
      officers removed: #{summary.officers_removed}
      unchanged:        #{summary.no_change}
      errors:           #{summary.errors}
    """)
  end
end
