defmodule Mix.Tasks.Members.Role do
  use Mix.Task

  @shortdoc "Sets a member's portal role (member, officer, or admin)"
  @moduledoc """
  Sets a member's portal role by email.

      mix members.role officer@tamu.edu officer
      mix members.role advisor@tamu.edu admin
      mix members.role former-officer@tamu.edu member

  This is useful for bootstrapping the first admin or recovering access when
  nobody can reach the officer management screen.
  """

  @roles ~w(member officer admin)

  @impl Mix.Task
  def run([email, role]) do
    Mix.Task.run("app.start")

    role =
      case role do
        "member" ->
          :member

        "officer" ->
          :officer

        "admin" ->
          :admin

        other ->
          Mix.raise("Invalid role #{inspect(other)}. Expected one of: #{Enum.join(@roles, ", ")}")
      end

    case IeeeTamuPortal.Accounts.get_member_by_email(String.trim(email)) do
      nil ->
        Mix.raise("No member account found with email #{email}")

      member ->
        case IeeeTamuPortal.Accounts.update_member_role(member, role) do
          {:ok, updated} ->
            Mix.shell().info("#{updated.email} is now #{updated.role}.")

          {:error, changeset} ->
            Mix.raise("Could not update role: #{inspect(changeset.errors)}")
        end
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix members.role EMAIL #{Enum.join(@roles, "|")}")
  end
end
