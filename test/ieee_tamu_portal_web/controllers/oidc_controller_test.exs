defmodule IeeeTamuPortalWeb.OIDCControllerTest do
  use IeeeTamuPortalWeb.ConnCase, async: true

  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.OIDC

  @redirect_uri "http://localhost:3000/api/auth/callback"
  @client_id "lounge-test"
  @client_secret "lounge-test-secret"

  describe "GET /.well-known/openid-configuration" do
    test "returns discovery metadata", %{conn: conn} do
      body = conn |> get("/.well-known/openid-configuration") |> json_response(200)

      assert body["issuer"] == "http://localhost:4000"
      assert body["authorization_endpoint"] == "http://localhost:4000/oauth/authorize"
      assert body["token_endpoint"] == "http://localhost:4000/oauth/token"
      assert body["userinfo_endpoint"] == "http://localhost:4000/oauth/userinfo"
      assert body["jwks_uri"] == "http://localhost:4000/oauth/jwks"
      assert "openid" in body["scopes_supported"]
      assert "role" in body["claims_supported"]
      assert body["code_challenge_methods_supported"] == ["S256"]
    end
  end

  describe "GET /oauth/jwks" do
    test "returns a usable RS256 signing key", %{conn: conn} do
      body = conn |> get("/oauth/jwks") |> json_response(200)
      assert %{"keys" => [key]} = body
      assert key["kty"] == "RSA"
      assert key["alg"] == "RS256"
      assert key["use"] == "sig"
      assert is_binary(key["kid"])
      assert is_binary(key["n"])
      assert is_binary(key["e"])
    end
  end

  describe "GET /oauth/authorize" do
    test "redirects unauthenticated members to the portal login", %{conn: conn} do
      {_verifier, challenge} = pkce()

      conn =
        get(
          conn,
          "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge))
        )

      assert redirected_to(conn) == ~p"/members/login"
    end

    test "rejects an unknown client", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)
      {_verifier, challenge} = pkce()

      body =
        conn
        |> get(
          "/oauth/authorize?" <>
            URI.encode_query(authorize_params(challenge, %{"client_id" => "nope"}))
        )
        |> json_response(400)

      assert body["error"] == "invalid_request"
    end

    test "rejects an unregistered redirect URI", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)
      {_verifier, challenge} = pkce()

      body =
        conn
        |> get(
          "/oauth/authorize?" <>
            URI.encode_query(
              authorize_params(challenge, %{"redirect_uri" => "https://evil.example/cb"})
            )
        )
        |> json_response(400)

      assert body["error"] == "invalid_request"
    end

    test "returns an authorization code and echoes state", %{conn: conn} do
      member = officer_member_fixture()
      conn = log_in_member(conn, member)
      {_verifier, challenge} = pkce()

      conn =
        get(
          conn,
          "/oauth/authorize?" <> URI.encode_query(authorize_params(challenge))
        )

      redirect = redirected_to(conn)
      assert redirect =~ @redirect_uri

      query = redirect |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert query["state"] == "state-123"
      assert is_binary(query["code"])

      assert {:ok, claims} = OIDC.verify_code(query["code"])
      assert claims[:sub] == member.id
      assert claims[:client_id] == @client_id
      assert claims[:code_challenge] == challenge
    end

    test "returns an error when PKCE is missing", %{conn: conn} do
      member = confirmed_member_fixture()
      conn = log_in_member(conn, member)

      params =
        authorize_params("a")
        |> Map.delete("code_challenge")
        |> Map.delete("code_challenge_method")

      redirect =
        conn
        |> get("/oauth/authorize?" <> URI.encode_query(params))
        |> redirected_to()

      query = redirect |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert query["error"] == "invalid_request"
      assert query["state"] == "state-123"
    end
  end

  describe "POST /oauth/token" do
    test "exchanges an authorization code for tokens", %{conn: conn} do
      member = officer_member_fixture()
      {verifier, challenge} = pkce()
      code = code_for(member, challenge)

      body =
        conn
        |> put_basic_auth()
        |> post("/oauth/token", token_params(code, verifier))
        |> json_response(200)

      assert body["token_type"] == "Bearer"
      assert body["expires_in"] == OIDC.access_token_ttl()
      assert body["scope"] == "openid profile email role"
      assert is_binary(body["access_token"])
      assert is_binary(body["id_token"])

      [public_key] = OIDC.jwks()["keys"]
      jwk = JOSE.JWK.from_map(public_key)

      assert {true, %JOSE.JWT{fields: claims}, _} =
               JOSE.JWT.verify_strict(jwk, ["RS256"], body["id_token"])

      assert claims["iss"] == "http://localhost:4000"
      assert claims["sub"] == Integer.to_string(member.id)
      assert claims["aud"] == @client_id
      assert claims["role"] == "officer"
      assert claims["nonce"] == "nonce-123"
      assert claims["email"] == member.email
      assert claims["email_verified"] == true
    end

    test "accepts client_secret_post authentication", %{conn: conn} do
      member = confirmed_member_fixture()
      {verifier, challenge} = pkce()
      code = code_for(member, challenge)

      body =
        conn
        |> post(
          "/oauth/token",
          Map.merge(token_params(code, verifier), %{
            "client_id" => @client_id,
            "client_secret" => @client_secret
          })
        )
        |> json_response(200)

      assert is_binary(body["access_token"])
    end

    test "rejects an invalid client secret", %{conn: conn} do
      member = confirmed_member_fixture()
      {verifier, challenge} = pkce()
      code = code_for(member, challenge)

      conn =
        conn
        |> put_req_header(
          "authorization",
          "Basic " <> Base.encode64("#{@client_id}:wrong-secret")
        )
        |> post("/oauth/token", token_params(code, verifier))

      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "invalid_client"
    end

    test "rejects a PKCE verifier that does not match", %{conn: conn} do
      member = confirmed_member_fixture()
      {_verifier, challenge} = pkce()
      code = code_for(member, challenge)
      {other_verifier, _challenge} = pkce()

      body =
        conn
        |> put_basic_auth()
        |> post("/oauth/token", token_params(code, other_verifier))
        |> json_response(400)

      assert body["error"] == "invalid_grant"
    end

    test "rejects a redirect_uri that does not match the code", %{conn: conn} do
      member = confirmed_member_fixture()
      {verifier, challenge} = pkce()
      code = code_for(member, challenge)

      body =
        conn
        |> put_basic_auth()
        |> post(
          "/oauth/token",
          token_params(code, verifier)
          |> Map.put("redirect_uri", "http://localhost:3000/other")
        )
        |> json_response(400)

      assert body["error"] == "invalid_grant"
    end

    test "rejects an expired or invalid code", %{conn: conn} do
      {verifier, _challenge} = pkce()

      body =
        conn
        |> put_basic_auth()
        |> post("/oauth/token", token_params("not-a-code", verifier))
        |> json_response(400)

      assert body["error"] == "invalid_grant"
    end

    test "rejects unsupported grant types", %{conn: conn} do
      body =
        conn
        |> put_basic_auth()
        |> post("/oauth/token", %{"grant_type" => "password"})
        |> json_response(400)

      assert body["error"] == "unsupported_grant_type"
    end
  end

  describe "GET /oauth/userinfo" do
    test "returns claims for a valid access token", %{conn: conn} do
      member = admin_member_fixture()
      {verifier, challenge} = pkce()
      code = code_for(member, challenge)

      body =
        conn
        |> put_basic_auth()
        |> post("/oauth/token", token_params(code, verifier))
        |> json_response(200)

      userinfo =
        conn
        |> put_req_header("authorization", "Bearer " <> body["access_token"])
        |> get("/oauth/userinfo")
        |> json_response(200)

      assert userinfo["sub"] == Integer.to_string(member.id)
      assert userinfo["email"] == member.email
      assert userinfo["email_verified"] == true
      assert userinfo["role"] == "admin"
      assert userinfo["name"] == member.email
    end

    test "rejects a missing or invalid bearer token", %{conn: conn} do
      missing = get(conn, "/oauth/userinfo")
      assert missing.status == 401
      assert json_response(missing, 401)["error"] == "invalid_token"

      invalid =
        conn
        |> put_req_header("authorization", "Bearer nope")
        |> get("/oauth/userinfo")

      assert invalid.status == 401
    end
  end

  defp pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp authorize_params(challenge, overrides \\ %{}) do
    Map.merge(
      %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "response_type" => "code",
        "scope" => "openid profile email role",
        "state" => "state-123",
        "nonce" => "nonce-123",
        "code_challenge" => challenge,
        "code_challenge_method" => "S256"
      },
      overrides
    )
  end

  defp token_params(code, verifier) do
    %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => @redirect_uri,
      "code_verifier" => verifier
    }
  end

  defp code_for(member, challenge) do
    OIDC.sign_code(%{
      sub: member.id,
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      code_challenge: challenge,
      scope: "openid profile email role",
      nonce: "nonce-123",
      auth_time: System.system_time(:second),
      jti: "test-jti"
    })
  end

  defp put_basic_auth(conn) do
    put_req_header(
      conn,
      "authorization",
      "Basic " <> Base.encode64("#{@client_id}:#{@client_secret}")
    )
  end
end
