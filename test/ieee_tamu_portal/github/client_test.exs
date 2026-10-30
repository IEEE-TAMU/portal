defmodule IeeeTamuPortal.Github.ClientTest do
  use ExUnit.Case, async: false

  alias IeeeTamuPortal.Github.Client

  setup do
    Application.put_env(:ieee_tamu_portal, :github_installation_token, "ghs_test_token")
    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :github_req_opts,
      plug: {Req.Test, Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :github_installation_token)
      Application.delete_env(:ieee_tamu_portal, :github_req_opts)
    end)

    :ok
  end

  test "gets an active team membership" do
    Req.Test.expect(Client, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/orgs/IEEE-TAMU/teams/members/memberships/octocat"
      Req.Test.json(conn, %{"state" => "active", "role" => "member"})
    end)

    assert {:ok, %{"state" => "active"}} =
             Client.get_team_membership("IEEE-TAMU", "members", "octocat")
  end

  test "treats a missing team membership as :not_member" do
    Req.Test.expect(Client, fn conn ->
      Plug.Conn.resp(conn, 404, Jason.encode!(%{"message" => "Not Found"}))
    end)

    assert {:ok, :not_member} =
             Client.get_team_membership("IEEE-TAMU", "members", "octocat")
  end

  test "adds a team member" do
    Req.Test.expect(Client, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/orgs/IEEE-TAMU/teams/officers/memberships/octocat"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"role" => "member"} = Jason.decode!(body)

      Req.Test.json(conn, %{"state" => "active", "role" => "member"})
    end)

    assert {:ok, %{"state" => "active"}} =
             Client.add_team_member("IEEE-TAMU", "officers", "octocat")
  end

  test "removes a team member" do
    Req.Test.expect(Client, fn conn ->
      assert conn.method == "DELETE"
      Plug.Conn.resp(conn, 204, "")
    end)

    assert :ok = Client.remove_team_member("IEEE-TAMU", "officers", "octocat")
  end

  test "treats a missing membership on delete as success" do
    Req.Test.expect(Client, fn conn ->
      Plug.Conn.resp(conn, 404, Jason.encode!(%{"message" => "Not Found"}))
    end)

    assert :ok = Client.remove_team_member("IEEE-TAMU", "officers", "octocat")
  end
end
