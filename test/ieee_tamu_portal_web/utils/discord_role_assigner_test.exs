defmodule IeeeTamuPortalWeb.Utils.DiscordRoleAssignerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias IeeeTamuPortalWeb.Utils.DiscordRoleAssigner

  @host "http://portal.test"

  setup do
    Req.Test.set_req_test_to_shared()

    # Summary logs are emitted at :info, which the test env suppresses.
    Logger.configure(level: :info)

    Application.put_env(:ieee_tamu_portal, :discord_role_assigner_req_opts,
      plug: {Req.Test, DiscordRoleAssigner},
      retry: false
    )

    on_exit(fn ->
      Logger.configure(level: :warning)
      Application.delete_env(:ieee_tamu_portal, :discord_role_assigner_req_opts)
    end)

    :ok
  end

  defp write_csv(content) do
    path = Path.join(System.tmp_dir!(), "roles-#{System.unique_integer()}.csv")
    File.write!(path, content)

    on_exit(fn -> File.rm(path) end)

    path
  end

  test "assign/4 with dry_run parses the CSV without HTTP calls" do
    path =
      write_csv("""
      member,officer
      # a comment cell is ignored
      a@tamu.edu,
      b@tamu.edu,y
      """)

    assert {:ok, summary} = DiscordRoleAssigner.assign(@host, "key", path, dry_run: true)

    # a→member, b→member, b→officer
    assert summary.total_pairs == 3
    assert summary.succeeded == 3
    assert summary.failed == 0
    assert summary.errors == []
  end

  test "assign/4 posts each pair and reports mixed results" do
    path =
      write_csv("""
      member
      a@tamu.edu
      b@tamu.edu
      """)

    Req.Test.expect(DiscordRoleAssigner, fn conn ->
      assert conn.body_params["email"] == "a@tamu.edu"
      assert conn.body_params["role"] == "member"

      Req.Test.json(conn, %{"ok" => true})
    end)

    Req.Test.expect(DiscordRoleAssigner, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(403, Jason.encode!(%{"error" => "nope"}))
    end)

    log =
      capture_log(fn ->
        assert {:ok, summary} = DiscordRoleAssigner.assign(@host, "key", path)
        send(self(), {:summary, summary})
      end)

    assert_received {:summary, summary}

    assert summary.total_pairs == 2
    assert summary.succeeded == 1
    assert summary.failed == 1
    assert [{_pair, {:unexpected_status, 403, _}}] = summary.errors
    assert log =~ "[DiscordRoleAssigner] TotalPairs=2 Succeeded=1 Failed=1"
  end

  test "assign/4 returns an error when the file does not exist" do
    assert {:error, :enoent} = DiscordRoleAssigner.assign(@host, "key", "/does/not/exist.csv")
  end
end
