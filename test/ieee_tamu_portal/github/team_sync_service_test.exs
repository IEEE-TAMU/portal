defmodule IeeeTamuPortal.Github.TeamSyncServiceTest do
  use IeeeTamuPortal.DataCase, async: false

  import IeeeTamuPortal.AccountsFixtures
  import IeeeTamuPortal.SettingsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Github.{Client, TeamSyncService}

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

    start_supervised!(TeamSyncService)

    :ok
  end

  test "force_sync_all/0 syncs linked members" do
    member = member_with_github() |> paid()
    stub_teams()

    assert {:ok, summary} = TeamSyncService.force_sync_all()
    assert summary.total == 1
    assert summary.members_added == 1
    assert summary.errors == 0
    assert Accounts.get_member!(member.id).id == member.id
  end

  test "sync_member/1 queues a per-member sync" do
    member = member_with_github() |> paid()
    stub_teams()

    TeamSyncService.sync_member(member)
    :sys.get_state(TeamSyncService)

    assert Process.whereis(TeamSyncService)
  end

  defp member_with_github do
    member = confirmed_member_fixture()

    {:ok, _auth} =
      Accounts.link_auth_method(member, %{
        provider: :github,
        sub: "123",
        preferred_username: "octocat",
        email: member.email
      })

    member
  end

  defp paid(member) do
    {:ok, registration} = IeeeTamuPortal.Members.get_or_create_registration(member, 2026)
    {:ok, _} = IeeeTamuPortal.Members.update_registration(registration, %{payment_override: true})
    member
  end

  defp stub_teams do
    Req.Test.stub(Client, fn conn ->
      cond do
        conn.method == "GET" ->
          Plug.Conn.resp(conn, 404, Jason.encode!(%{"message" => "Not Found"}))

        conn.method == "PUT" ->
          Req.Test.json(conn, %{"state" => "active", "role" => "member"})

        conn.method == "DELETE" ->
          Plug.Conn.resp(conn, 204, "")
      end
    end)
  end
end
