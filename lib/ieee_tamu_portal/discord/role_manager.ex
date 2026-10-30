defmodule IeeeTamuPortal.Discord.RoleManager do
  @moduledoc """
  Manages Discord roles based on member authentication, payment status, and
  portal role.

  This module contains the business logic for determining which Discord roles
  a member should have based on their:
  - Discord account linking status
  - Payment/registration status for the current year
  - Portal role (`:officer` and `:admin` are both treated as officers)

  The managed roles are:

  - `Member` — granted when the member has a valid paid registration
  - `Officer` — granted when the member has the `:officer` or `:admin` portal role
  """

  alias IeeeTamuPortal.{Accounts, Settings}
  alias IeeeTamuPortal.Discord.Client
  alias IeeeTamuPortal.Members.Registration

  require Logger

  @member_role "Member"
  @default_officer_role "Officer"

  @doc """
  Synchronizes all managed Discord roles for a member based on their current
  status.

  This function should be called whenever:
  - A member links/unlinks their Discord account
  - A member's payment status changes
  - A member's portal role changes
  - Administrative changes affect member status

  Returns `{:ok, actions_taken}` or `{:error, reason}`.
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

  Kept as a separate entry point for callers that only need the paid-member
  role. Most callers should use `sync_member_roles/1` instead.
  """
  def sync_member_role(member, discord_auth) do
    discord_user_id = discord_auth.sub

    case fetch_roles(discord_user_id) do
      {:ok, roles} ->
        reconcile_role(
          roles,
          discord_user_id,
          member.id,
          @member_role,
          should_have_member_role?(member)
        )

      {:error, :not_in_guild} ->
        log_not_in_guild(discord_user_id, member.id)
        {:ok, :not_in_guild}

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
  Determines if a member should have the Officer role.

  Admins are treated as officers because they have all officer privileges plus
  role management.
  """
  def should_have_officer_role?(member), do: Accounts.Member.officer?(member)

  @doc """
  Returns the configured Discord role name for officers.

  Defaults to `"Officer"` and can be overridden with `DISCORD_OFFICER_ROLE`.
  """
  def officer_role_name do
    case Application.get_env(:ieee_tamu_portal, :discord_officer_role, @default_officer_role) do
      name when is_binary(name) and name != "" -> name
      _ -> @default_officer_role
    end
  end

  @doc """
  Removes every Discord role managed by the portal from a Discord user.

  Used when a member unlinks their Discord account. Failures are logged but do
  not prevent the unlink from succeeding.
  """
  def remove_managed_roles(discord_user_id) do
    [@member_role, officer_role_name()]
    |> Enum.uniq()
    |> Enum.each(fn role_name ->
      case Client.remove_role(discord_user_id, role_name) do
        {:ok, _response} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to remove #{role_name} role from Discord user #{discord_user_id}: #{reason}"
          )
      end
    end)

    :ok
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
        case sync_roles_for_discord_member(member, discord_auth) do
          {:ok, actions} -> {member.id, actions}
          {:error, reason} -> {member.id, {:error, reason}}
        end
      end)

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
        &summarize_result/2
      )

    Logger.info("Discord role synchronization complete: #{inspect(summary)}")
    {:ok, summary}
  end

  # Private helper functions

  defp sync_roles_for_discord_member(member, discord_auth) do
    discord_user_id = discord_auth.sub

    case fetch_roles(discord_user_id) do
      {:ok, roles} ->
        with {:ok, member_action} <-
               reconcile_role(
                 roles,
                 discord_user_id,
                 member.id,
                 @member_role,
                 should_have_member_role?(member)
               ),
             {:ok, officer_action} <-
               reconcile_role(
                 roles,
                 discord_user_id,
                 member.id,
                 officer_role_name(),
                 should_have_officer_role?(member)
               ) do
          {:ok, %{member_role: member_action, officer_role: officer_action}}
        end

      # The member left the Discord server — there is nothing to sync.
      {:error, :not_in_guild} ->
        log_not_in_guild(discord_user_id, member.id)
        {:ok, %{member_role: :not_in_guild, officer_role: :not_in_guild}}

      {:error, reason} ->
        Logger.error("Failed to check roles for member #{member.id}: #{reason}")
        {:error, reason}
    end
  end

  defp fetch_roles(discord_user_id) do
    case Client.get_user_roles(discord_user_id) do
      {:ok, %{"success" => true, "roles" => roles}} when is_list(roles) ->
        {:ok, roles}

      {:ok, %{"success" => true}} ->
        {:ok, []}

      {:ok, %{"success" => false, "message" => message}} ->
        {:error, message}

      {:ok, body} ->
        {:error, "Unexpected roles response: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reconcile_role(roles, discord_user_id, member_id, role_name, should_have_role?) do
    has_role? = Enum.any?(roles, fn role -> role["name"] == role_name end)

    cond do
      should_have_role? and not has_role? ->
        case Client.add_role(discord_user_id, role_name) do
          {:ok, _response} ->
            Logger.info(
              "Added #{role_name} role to Discord user #{discord_user_id} for member #{member_id}"
            )

            {:ok, :role_added}

          {:error, reason} ->
            Logger.error("Failed to add #{role_name} role for member #{member_id}: #{reason}")

            {:error, reason}
        end

      not should_have_role? and has_role? ->
        case Client.remove_role(discord_user_id, role_name) do
          {:ok, _response} ->
            Logger.info(
              "Removed #{role_name} role from Discord user #{discord_user_id} for member #{member_id}"
            )

            {:ok, :role_removed}

          {:error, reason} ->
            Logger.error("Failed to remove #{role_name} role for member #{member_id}: #{reason}")

            {:error, reason}
        end

      true ->
        {:ok, :no_change_needed}
    end
  end

  defp log_not_in_guild(discord_user_id, member_id) do
    Logger.info(
      "Discord user #{discord_user_id} not in guild — skipping role sync for member #{member_id}"
    )
  end

  defp summarize_result({_member_id, {:error, _reason}}, acc) do
    %{acc | total: acc.total + 1, errors: acc.errors + 1}
  end

  defp summarize_result(
         {_member_id, %{member_role: member_action, officer_role: officer_action}},
         acc
       ) do
    actions = [member_action, officer_action]
    acc = %{acc | total: acc.total + 1}

    cond do
      Enum.any?(actions, &match?({:error, _}, &1)) ->
        %{acc | errors: acc.errors + 1}

      Enum.any?(actions, &(&1 in [:role_added, :role_removed])) ->
        %{
          acc
          | roles_added: acc.roles_added + Enum.count(actions, &(&1 == :role_added)),
            roles_removed: acc.roles_removed + Enum.count(actions, &(&1 == :role_removed))
        }

      true ->
        # Includes members who left the guild: no role changes are needed.
        %{acc | no_change: acc.no_change + 1}
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
