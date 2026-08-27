defmodule IeeeTamuPortal.Mautic.ClientTest do
  use IeeeTamuPortal.DataCase, async: false

  import ExUnit.CaptureLog

  alias IeeeTamuPortal.Mautic.Client

  @password "super-secret-password"

  setup do
    # The Mautic config is a keyword list (see config/runtime.exs).
    Application.put_env(:ieee_tamu_portal, :mautic,
      base_url: "http://mautic.test",
      username: "ieee-portal",
      password: @password
    )

    Req.Test.set_req_test_to_shared()

    Application.put_env(:ieee_tamu_portal, :mautic_req_opts,
      plug: {Req.Test, IeeeTamuPortal.Mautic.Client},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :mautic)
      Application.delete_env(:ieee_tamu_portal, :mautic_req_opts)
    end)

    :ok
  end

  describe "config!/0" do
    test "normalizes keyword list config to a map" do
      config = Client.config!()

      assert is_map(config)
      assert config[:base_url] == "http://mautic.test"
      assert config[:username] == "ieee-portal"
      assert config[:password] == @password
    end

    test "raises when Mautic is not configured" do
      Application.delete_env(:ieee_tamu_portal, :mautic)

      assert_raise RuntimeError, ~r/Mautic configuration not found/, fn ->
        Client.config!()
      end
    end
  end

  describe "create_contacts_batch/1" do
    test "posts contacts and returns the body on success" do
      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        Req.Test.json(conn, %{"contacts" => %{"1" => %{"id" => 1}}})
      end)

      assert {:ok, %{"contacts" => %{"1" => %{"id" => 1}}}} =
               Client.create_contacts_batch([%{"email" => "member@tamu.edu"}])
    end

    test "returns {:error, reason} on HTTP error without leaking credentials" do
      Req.Test.expect(IeeeTamuPortal.Mautic.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "nope"}))
      end)

      log =
        capture_log(fn ->
          assert {:error, "HTTP 500"} =
                   Client.create_contacts_batch([%{"email" => "member@tamu.edu"}])
        end)

      refute log =~ @password
      assert log =~ "Mautic API error (HTTP 500)"
    end
  end
end
