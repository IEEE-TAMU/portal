defmodule IeeeTamuPortal.Discord.RoleManager do
  @moduledoc """
  Manages Discord roles based on member authentication and payment status.

  This module contains the business logic for determining which Discord roles
  a member should have based on their:
  - Discord account linking status
  - Payment/registration status for the current year

  The primary role managed is "Member" which is granted when:
  1. The member has linked their Discord account
  2. The member has a valid paid registration (payment or override)
  """

  alias IeeeTamuPortal.{Accounts, Settings}
  alias IeeeTamuPortal.Discord.Client
  alias IeeeTamuPortal.Members.Registration

  require Logger

  @member_role "Member"

  @doc """
  Synchronizes Discord roles for a member based on their current status.

  This function should be called whenever:
  - A member links/unlinks their Discord account
  - A member's payment status changes
  - Administrative changes affect member status

  Returns {:ok, actions_taken} or {:error, reason}.
  """
  def sync_member_roles(member) do
    member = Accounts.preload_member_auth_methods(member)

    case get_discord_auth_method(member) do
      nil ->
        # No Discord account linked, nothing to do
        {:ok, :no_discord_account}

      discord_auth ->
        sync_roles_for_discord_member(member, discord_auth)
    end
  end

  @doc """
  Synchronizes the Member role specifically for a Discord-linked member.
  """
  def sync_member_role(member, discord_auth) do
    should_have_member_role = should_have_member_role?(member)
    discord_user_id = discord_auth.sub

    case Client.has_role?(discord_user_id, @member_role) do
      {:ok, has_role} ->
        cond do
          should_have_member_role and not has_role ->
            case Client.add_role(discord_user_id, @member_role) do
              {:ok, _response} ->
                Logger.info(
                  "Added Member role to Discord user #{discord_user_id} for member #{member.id}"
                )

                {:ok, :role_added}

              {:error, reason} ->
                Logger.error("Failed to add Member role for member #{member.id}: #{reason}")
                {:error, reason}
            end

          not should_have_member_role and has_role ->
            case Client.remove_role(discord_user_id, @member_role) do
              {:ok, _response} ->
                Logger.info(
                  "Removed Member role from Discord user #{discord_user_id} for member #{member.id}"
                )

                {:ok, :role_removed}

              {:error, reason} ->
                Logger.error("Failed to remove Member role for member #{member.id}: #{reason}")
                {:error, reason}
            end

          true ->
            # Role status is already correct
            {:ok, :no_change_needed}
        end

      {:error, reason} ->
        Logger.error("Failed to check role status for member #{member.id}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Determines if a member should have the Member role.

  A member should have the Member role if they have a valid paid registration
  for the current year.
  """
  def should_have_member_role?(member) do
    current_year = Settings.get_registration_year!()
    Registration.member_paid_for_year?(member.id, current_year)
  end

  @doc """
  Synchronizes roles for all members with Discord accounts.

  This is useful for bulk operations or periodic synchronization.
  Returns a summary of actions taken.
  """
  def sync_all_discord_members do
    Logger.info("Starting bulk Discord role synchronization")

    # Get all members with Discord auth methods
    members_with_discord = get_all_members_with_discord()

    results =
      Enum.map(members_with_discord, fn {member, discord_auth} ->
        case sync_member_role(member, discord_auth) do
          {:ok, action} -> {member.id, action}
          {:error, reason} -> {member.id, {:error, reason}}
        end
      end)

    # Summarize results
    summary =
      Enum.reduce(
        results,
        %{
          total: 0,
          roles_added: 0,
          roles_removed: 0,
          no_change: 0,
          errors: 0
        },
        fn {_member_id, result}, acc ->
          acc = %{acc | total: acc.total + 1}

          case result do
            :role_added -> %{acc | roles_added: acc.roles_added + 1}
            :role_removed -> %{acc | roles_removed: acc.roles_removed + 1}
            :no_change_needed -> %{acc | no_change: acc.no_change + 1}
            {:error, _} -> %{acc | errors: acc.errors + 1}
          end
        end
      )

    Logger.info("Discord role synchronization complete: #{inspect(summary)}")
    {:ok, summary}
  end

  # Private helper functions

  defp sync_roles_for_discord_member(member, discord_auth) do
    case sync_member_role(member, discord_auth) do
      {:ok, action} ->
        {:ok, %{member_role: action}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_discord_auth_method(member) do
    Enum.find(member.secondary_auth_methods, &(&1.provider == :discord))
  end

  defp get_all_members_with_discord do
    import Ecto.Query

    from(m in IeeeTamuPortal.Accounts.Member,
      join: auth in IeeeTamuPortal.Accounts.AuthMethod,
      on: auth.member_id == m.id,
      where: auth.provider == :discord,
      select: {m, auth}
    )
    |> IeeeTamuPortal.Repo.all()
  end
end
