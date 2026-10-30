defmodule Mix.Tasks.Members.Roles do
  use Mix.Task

  @shortdoc "Lists members with officer or admin access"
  @moduledoc """
  Lists the member accounts that can access the admin panel.

      mix members.roles
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    members = IeeeTamuPortal.Accounts.list_privileged_members()

    if members == [] do
      Mix.shell().info("No officers or admins configured.")
    else
      Mix.shell().info("EMAIL\tROLE")

      Enum.each(members, fn member ->
        Mix.shell().info("#{member.email}\t#{member.role}")
      end)
    end
  end
end
