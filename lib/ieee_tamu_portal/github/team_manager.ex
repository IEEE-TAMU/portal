defmodule IeeeTamuPortal.Github.TeamManager do
  @moduledoc """
  Keeps GitHub organization team membership in sync with portal status.

  Managed teams:

  - `Members` — paid current-year members, plus officers and admins
  - `Officers` — officers and admins

  GitHub team membership is independent of local dues for officers: officers
  are expected to maintain global IEEE membership, not necessarily pay local
  branch dues. Admins are treated as officers.
  """

  require Logger

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.Github.Client
  alias IeeeTamuPortal.Members.Registration
  alias IeeeTamuPortal.Settings

  @doc """
  Synchronizes all managed GitHub teams for a single member.
  """
  def sync_member_teams(member) do
    member = Accounts.preload_member_auth_methods(member)

    case github_auth(member) do
      %{preferred_username: username} when is_binary(username) and username != "" ->
        sync_teams(member, username)

      %{} ->
        {:error, :missing_github_username}

      nil ->
        {:ok, :no_github_account}
    end
  end

  @doc """
  Determines whether a member should be in the Members team.
  """
  def should_have_members_team?(member) do
    Member.officer?(member) or paid_for_current_year?(member)
  end

  @doc """
  Determines whether a member should be in the Officers team.
  """
  def should_have_officers_team?(member), do: Member.officer?(member)

  @doc """
  Removes all portal-managed team memberships for a GitHub username.

  Used when a member unlinks their GitHub account. Failures are logged but do
  not prevent the unlink from succeeding.
  """
  def remove_managed_teams(username) when is_binary(username) and username != "" do
    Enum.each(managed_teams(), fn team_slug ->
      case Client.remove_team_member(org(), team_slug, username) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to remove GitHub user #{username} from team #{team_slug}: #{reason}"
          )
      end
    end)

    :ok
  end

  def remove_managed_teams(_username), do: :ok

  @doc """
  Synchronizes GitHub team membership for every member with a linked GitHub
  account.
  """
  def sync_all_github_members do
    Logger.info("Starting bulk GitHub team synchronization")

    results =
      get_all_members_with_github()
      |> Enum.map(fn {member, auth} ->
        username = auth.preferred_username

        if is_binary(username) and username != "" do
          case sync_teams(member, username) do
            {:ok, actions} -> {member.id, actions}
            {:error, reason} -> {member.id, {:error, reason}}
          end
        else
          {member.id, {:error, :missing_github_username}}
        end
      end)

    summary =
      Enum.reduce(
        results,
        %{
          total: 0,
          members_added: 0,
          members_removed: 0,
          officers_added: 0,
          officers_removed: 0,
          no_change: 0,
          errors: 0
        },
        &summarize_result/2
      )

    Logger.info("GitHub team synchronization complete: #{inspect(summary)}")
    {:ok, summary}
  end

  @doc """
  Returns the configured organization slug.
  """
  def org, do: Application.get_env(:ieee_tamu_portal, :github_org, "IEEE-TAMU")

  @doc """
  Returns the configured Members team slug.
  """
  def members_team do
    Application.get_env(:ieee_tamu_portal, :github_members_team, "members")
  end

  @doc """
  Returns the configured Officers team slug.
  """
  def officers_team do
    Application.get_env(:ieee_tamu_portal, :github_officers_team, "officers")
  end

  defp managed_teams, do: Enum.uniq([members_team(), officers_team()])

  defp sync_teams(member, username) do
    members_result =
      reconcile(
        members_team(),
        username,
        should_have_members_team?(member)
      )

    officers_result =
      reconcile(
        officers_team(),
        username,
        should_have_officers_team?(member)
      )

    case {members_result, officers_result} do
      {{:ok, members_action}, {:ok, officers_action}} ->
        {:ok, %{members_team: members_action, officers_team: officers_action}}

      {{:error, reason}, _} ->
        {:error, reason}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  defp reconcile(team_slug, username, should_have_membership?) do
    case Client.get_team_membership(org(), team_slug, username) do
      {:ok, :not_member} ->
        if should_have_membership? do
          add_member(team_slug, username)
        else
          {:ok, :no_change_needed}
        end

      {:ok, %{"state" => state}}
      when state in ["active", "pending"] ->
        if should_have_membership? do
          {:ok, :no_change_needed}
        else
          remove_member(team_slug, username)
        end

      {:ok, other} ->
        {:error, "Unexpected team membership response: #{inspect(other)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_member(team_slug, username) do
    case Client.add_team_member(org(), team_slug, username) do
      {:ok, _body} ->
        Logger.info("Added GitHub user #{username} to team #{team_slug}")
        {:ok, :member_added}

      {:error, reason} ->
        Logger.error("Failed to add GitHub user #{username} to team #{team_slug}: #{reason}")
        {:error, reason}
    end
  end

  defp remove_member(team_slug, username) do
    case Client.remove_team_member(org(), team_slug, username) do
      :ok ->
        Logger.info("Removed GitHub user #{username} from team #{team_slug}")
        {:ok, :member_removed}

      {:error, reason} ->
        Logger.error("Failed to remove GitHub user #{username} from team #{team_slug}: #{reason}")
        {:error, reason}
    end
  end

  defp paid_for_current_year?(member) do
    current_year = Settings.get_registration_year!()
    Registration.member_paid_for_year?(member.id, current_year)
  end

  defp github_auth(member) do
    Enum.find(member.secondary_auth_methods, &(&1.provider == :github))
  end

  defp summarize_result({_member_id, {:error, _reason}}, acc) do
    %{acc | total: acc.total + 1, errors: acc.errors + 1}
  end

  defp summarize_result(
         {_member_id, %{members_team: members_action, officers_team: officers_action}},
         acc
       ) do
    acc = %{acc | total: acc.total + 1}

    cond do
      Enum.any?([members_action, officers_action], &match?({:error, _}, &1)) ->
        %{acc | errors: acc.errors + 1}

      members_action == :member_added or officers_action == :member_added or
        members_action == :member_removed or officers_action == :member_removed ->
        %{
          acc
          | members_added: acc.members_added + count_action(members_action, :member_added),
            members_removed: acc.members_removed + count_action(members_action, :member_removed),
            officers_added: acc.officers_added + count_action(officers_action, :member_added),
            officers_removed:
              acc.officers_removed + count_action(officers_action, :member_removed)
        }

      true ->
        %{acc | no_change: acc.no_change + 1}
    end
  end

  defp count_action(action, expected), do: if(action == expected, do: 1, else: 0)

  defp get_all_members_with_github do
    import Ecto.Query

    from(m in Member,
      join: auth in IeeeTamuPortal.Accounts.AuthMethod,
      on: auth.member_id == m.id,
      where: auth.provider == :github,
      select: {m, auth}
    )
    |> IeeeTamuPortal.Repo.all()
  end
end
