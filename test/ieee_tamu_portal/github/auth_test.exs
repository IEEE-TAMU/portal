defmodule IeeeTamuPortal.Github.AuthTest do
  use ExUnit.Case, async: false

  alias IeeeTamuPortal.Github.Auth

  setup do
    key = :public_key.generate_key({:rsa, 2048, 65537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])

    Application.put_env(:ieee_tamu_portal, :github_app,
      app_id: "12345",
      installation_id: "67890",
      private_key: pem
    )

    Application.delete_env(:ieee_tamu_portal, :github_installation_token)

    Application.put_env(:ieee_tamu_portal, :github_req_opts,
      plug: {Req.Test, Auth},
      retry: false
    )

    Req.Test.set_req_test_to_shared()

    on_exit(fn ->
      Application.delete_env(:ieee_tamu_portal, :github_app)
      Application.delete_env(:ieee_tamu_portal, :github_installation_token)
      Application.delete_env(:ieee_tamu_portal, :github_req_opts)
    end)

    :ok
  end

  test "exchanges an app JWT for an installation token and caches it" do
    expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()

    Req.Test.expect(Auth, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/app/installations/67890/access_tokens"

      [authorization] = Plug.Conn.get_req_header(conn, "authorization")
      assert "Bearer " <> jwt = authorization
      assert length(String.split(jwt, ".")) == 3

      Req.Test.json(conn, %{"token" => "ghs_test_token", "expires_at" => expires_at})
    end)

    start_supervised!(Auth)

    assert {:ok, "ghs_test_token"} = Auth.token()
    assert {:ok, "ghs_test_token"} = Auth.token()
  end

  test "uses a static token when configured" do
    Application.put_env(:ieee_tamu_portal, :github_installation_token, "ghs_static")

    assert {:ok, "ghs_static"} = Auth.token()
  end
end
