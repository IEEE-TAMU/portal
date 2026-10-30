defmodule IeeeTamuPortal.Github.TeamManagerTest do
  use IeeeTamuPortal.DataCase, async: false

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Github.{Client, TeamManager}

  setup do
    registration_year_setting_fixture("2026")

    Application.put_env(:ieee_tamu_portal, :github_installation_token, "ghs_test_token")
    Application.put_env(:ieee_tamu_portal, :github_org, "IEEE-TAMU")
    Application.put_env(:ieee_tamu_portal, :github_members_team, "members")
    Application.put_env(:ieee_tamu_portal, :github_officers_team, "officers")

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :github_req_opts,
      plug: {Req.Test, Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :github_installation_token)
      Application.delete_env(:ieee_tamu_portal, :github_org)
      Application.delete_env(:ieee_tamu_portal, :github_members_team)
      Application.delete_env(:ieee_tamu_portal, :github_officers_team)
      Application.delete_env(:ieee_tamu_portal, :github_req_opts)
    end)

    :ok
  end

  test "returns :no_github_account when no GitHub account is linked" do
    assert {:ok, :no_github_account} =
             TeamManager.sync_member_teams(confirmed_member_fixture())
  end

  test "returns an error when the linked GitHub account has no username" do
    member = confirmed_member_fixture()

    {:ok, _auth} =
      Accounts.link_auth_method(member, %{provider: :github, sub: "123"})

    assert {:error, :missing_github_username} = TeamManager.sync_member_teams(member)
  end

  test "adds a paid member to Members but not Officers" do
    member = member_with_github() |> paid()
    stub_teams(members: :not_member, officers: :not_member)

    assert {:ok, %{members_team: :member_added, officers_team: :no_change_needed}} =
             TeamManager.sync_member_teams(member)
  end

  test "removes an unpaid regular member from Members" do
    member = member_with_github()
    stub_teams(members: :active, officers: :not_member)

    assert {:ok, %{members_team: :member_removed, officers_team: :no_change_needed}} =
             TeamManager.sync_member_teams(member)
  end

  test "adds an unpaid officer to both Members and Officers" do
    member = member_with_github(:officer)
    stub_teams(members: :not_member, officers: :not_member)

    assert {:ok, %{members_team: :member_added, officers_team: :member_added}} =
             TeamManager.sync_member_teams(member)
  end

  test "treats admins as officers" do
    member = member_with_github(:admin)
    stub_teams(members: :not_member, officers: :not_member)

    assert {:ok, %{members_team: :member_added, officers_team: :member_added}} =
             TeamManager.sync_member_teams(member)
  end

  test "leaves correct memberships unchanged" do
    member = member_with_github() |> paid()
    stub_teams(members: :active, officers: :not_member)

    assert {:ok, %{members_team: :no_change_needed, officers_team: :no_change_needed}} =
             TeamManager.sync_member_teams(member)
  end

  test "summarizes a bulk sync" do
    member_with_github() |> paid()
    member_with_github(:officer, "officer-1", "octocat-officer")
    stub_teams(members: :not_member, officers: :not_member)

    assert {:ok, summary} = TeamManager.sync_all_github_members()

    assert summary.total == 2
    assert summary.members_added == 2
    assert summary.officers_added == 1
    assert summary.errors == 0
  end

  test "removes both managed teams when unlinking" do
    stub_teams(members: :active, officers: :active)

    assert :ok = TeamManager.remove_managed_teams("octocat")
  end

  defp member_with_github(role \\ :member, sub \\ "123", username \\ "octocat") do
    member = confirmed_member_fixture()

    {:ok, _auth} =
      Accounts.link_auth_method(member, %{
        provider: :github,
        sub: sub,
        preferred_username: username,
        email: member.email
      })

    if role == :member do
      member
    else
      {:ok, member} = Accounts.update_member_role(member, role)
      member
    end
  end

  defp paid(member) do
    {:ok, registration} = IeeeTamuPortal.Members.get_or_create_registration(member, 2026)
    {:ok, _} = IeeeTamuPortal.Members.update_registration(registration, %{payment_override: true})
    member
  end

  defp stub_teams(opts) do
    members_state = Keyword.fetch!(opts, :members)
    officers_state = Keyword.fetch!(opts, :officers)

    Req.Test.stub(Client, fn conn ->
      cond do
        conn.method == "GET" and
            String.ends_with?(conn.request_path, "/teams/members/memberships/octocat") ->
          membership_response(conn, members_state)

        conn.method == "GET" and
            String.ends_with?(conn.request_path, "/teams/members/memberships/octocat-officer") ->
          membership_response(conn, members_state)

        conn.method == "GET" and
            String.ends_with?(conn.request_path, "/teams/officers/memberships/octocat") ->
          membership_response(conn, officers_state)

        conn.method == "GET" and
            String.ends_with?(conn.request_path, "/teams/officers/memberships/octocat-officer") ->
          membership_response(conn, officers_state)

        conn.method == "PUT" ->
          Req.Test.json(conn, %{"state" => "active", "role" => "member"})

        conn.method == "DELETE" ->
          Plug.Conn.resp(conn, 204, "")
      end
    end)
  end

  defp membership_response(conn, :not_member) do
    Plug.Conn.resp(conn, 404, Jason.encode!(%{"message" => "Not Found"}))
  end

  defp membership_response(conn, :active) do
    Req.Test.json(conn, %{"state" => "active", "role" => "member"})
  end
end
