defmodule IeeeTamuPortalWeb.OIDCController do
  @moduledoc """
  OpenID Connect provider endpoints used by first-party IEEE TAMU apps.

  The portal is the identity provider. Clients such as the lounge app send the
  member through `/oauth/authorize`; the portal reuses its existing member
  session, then returns an authorization code to the client.
  """

  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.{Accounts, OIDC}
  alias IeeeTamuPortal.OIDC.Clients

  @basic_realm ~s(Basic realm="portal")

  def discovery(conn, _params) do
    issuer = OIDC.issuer()

    json(conn, %{
      issuer: issuer,
      authorization_endpoint: issuer <> "/oauth/authorize",
      token_endpoint: issuer <> "/oauth/token",
      userinfo_endpoint: issuer <> "/oauth/userinfo",
      jwks_uri: issuer <> "/oauth/jwks",
      scopes_supported: OIDC.scopes(),
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code"],
      subject_types_supported: ["public"],
      id_token_signing_alg_values_supported: ["RS256"],
      token_endpoint_auth_methods_supported: ["client_secret_basic", "client_secret_post"],
      code_challenge_methods_supported: ["S256"],
      claims_supported: OIDC.claims()
    })
  end

  def jwks(conn, _params), do: json(conn, OIDC.jwks())

  def authorize(conn, params) do
    client = OIDC.get_client(params["client_id"])
    redirect_uri = params["redirect_uri"]

    cond do
      is_nil(client) ->
        oauth_error(conn, :bad_request, "invalid_request", "Unknown client_id.")

      not OIDC.redirect_uri_allowed?(client, redirect_uri) ->
        oauth_error(
          conn,
          :bad_request,
          "invalid_request",
          "redirect_uri is not registered for this client."
        )

      params["response_type"] != "code" ->
        redirect_error(
          conn,
          redirect_uri,
          params["state"],
          "unsupported_response_type",
          "Only the authorization code flow is supported."
        )

      not valid_scope?(params["scope"], client) ->
        redirect_error(
          conn,
          redirect_uri,
          params["state"],
          "invalid_scope",
          "The openid scope is required."
        )

      not valid_pkce?(params) ->
        redirect_error(
          conn,
          redirect_uri,
          params["state"],
          "invalid_request",
          "PKCE with the S256 method is required."
        )

      true ->
        member = Accounts.preload_member_info(conn.assigns.current_member)
        auth_time = System.system_time(:second)
        jti = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

        code =
          OIDC.sign_code(%{
            sub: member.id,
            client_id: Clients.client_id(client),
            redirect_uri: redirect_uri,
            code_challenge: params["code_challenge"],
            scope: params["scope"],
            nonce: params["nonce"],
            auth_time: auth_time,
            jti: jti
          })

        query = %{"code" => code}
        query = maybe_put_state(query, params["state"])

        redirect(conn, external: append_query(redirect_uri, query))
    end
  end

  def token(conn, params) do
    conn =
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("pragma", "no-cache")

    with {:ok, client} <- authenticate_client(conn, params),
         :ok <- validate_grant_type(params),
         {:ok, claims} <- validate_code(params["code"]),
         :ok <- validate_code_client(claims, client),
         :ok <- validate_code_redirect(claims, params["redirect_uri"]),
         :ok <- validate_pkce(claims, params["code_verifier"]),
         {:ok, member} <- fetch_member(claims[:sub]) do
      client_id = Clients.client_id(client)
      Clients.mark_used_by_client_id(client_id)

      access_token =
        OIDC.sign_access_token(%{
          sub: member.id,
          client_id: client_id,
          scope: claims[:scope],
          auth_time: claims[:auth_time]
        })

      id_token =
        OIDC.id_token(member, client_id, claims[:nonce], claims[:auth_time], claims[:scope])

      json(conn, %{
        access_token: access_token,
        token_type: "Bearer",
        expires_in: OIDC.access_token_ttl(),
        id_token: id_token,
        scope: claims[:scope]
      })
    else
      {:error, :invalid_client} ->
        conn
        |> put_status(:unauthorized)
        |> put_resp_header("www-authenticate", @basic_realm)
        |> json(%{
          error: "invalid_client",
          error_description: "Client authentication failed."
        })

      {:error, error, description} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: error, error_description: description})
    end
  end

  def userinfo(conn, _params) do
    with ["Bearer " <> token | _] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- OIDC.verify_access_token(token),
         %Accounts.Member{} = member <- Accounts.get_member_with_info(claims[:sub]) do
      Clients.mark_used_by_client_id(claims[:client_id])
      json(conn, OIDC.userinfo(member, claims[:scope] || ""))
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_resp_header("www-authenticate", ~s(Bearer error="invalid_token"))
        |> json(%{error: "invalid_token"})
    end
  end

  defp authenticate_client(conn, params) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded | _] -> authenticate_basic(encoded)
      _ -> authenticate_post(params)
    end
  end

  defp authenticate_basic(encoded) do
    with {:ok, decoded} <- Base.decode64(encoded),
         [client_id, client_secret] <- String.split(decoded, ":", parts: 2),
         client when not is_nil(client) <- OIDC.get_client(client_id),
         true <- OIDC.client_secret_valid?(client, client_secret) do
      {:ok, client}
    else
      _ -> {:error, :invalid_client}
    end
  end

  defp authenticate_post(params) do
    client = OIDC.get_client(params["client_id"])

    if OIDC.client_secret_valid?(client, params["client_secret"]) do
      {:ok, client}
    else
      {:error, :invalid_client}
    end
  end

  defp validate_grant_type(%{"grant_type" => "authorization_code"}), do: :ok

  defp validate_grant_type(_) do
    {:error, "unsupported_grant_type", "Only authorization_code is supported."}
  end

  defp validate_code(code) do
    case OIDC.verify_code(code) do
      {:ok, claims} when is_map(claims) ->
        {:ok, claims}

      _ ->
        {:error, "invalid_grant", "The authorization code is invalid or expired."}
    end
  end

  defp validate_code_client(claims, client) do
    if claims[:client_id] == Clients.client_id(client) do
      :ok
    else
      {:error, "invalid_grant", "The authorization code was issued to another client."}
    end
  end

  defp validate_code_redirect(claims, redirect_uri) do
    if is_binary(redirect_uri) and claims[:redirect_uri] == redirect_uri do
      :ok
    else
      {:error, "invalid_grant", "redirect_uri does not match the authorization request."}
    end
  end

  defp validate_pkce(claims, verifier) do
    challenge = claims[:code_challenge]
    verifier = verifier || ""
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if is_binary(challenge) and byte_size(verifier) in 43..128 and
         Plug.Crypto.secure_compare(challenge, computed) do
      :ok
    else
      {:error, "invalid_grant", "PKCE verification failed."}
    end
  end

  defp fetch_member(sub) when is_integer(sub) do
    case Accounts.get_member_with_info(sub) do
      nil -> {:error, "invalid_grant", "The member no longer exists."}
      member -> {:ok, member}
    end
  end

  defp fetch_member(_), do: {:error, "invalid_grant", "The authorization code is invalid."}

  defp valid_scope?(scope, client) when is_binary(scope) do
    requested = String.split(scope, " ", trim: true)
    allowed = Clients.scopes(client)
    "openid" in requested and Enum.all?(requested, &(&1 in allowed))
  end

  defp valid_scope?(_, _), do: false

  defp valid_pkce?(params) do
    params["code_challenge_method"] == "S256" and
      is_binary(params["code_challenge"]) and
      byte_size(params["code_challenge"]) in 43..128
  end

  defp maybe_put_state(query, state) when is_binary(state) and state != "" do
    Map.put(query, "state", state)
  end

  defp maybe_put_state(query, _state), do: query

  defp append_query(uri, query) do
    separator = if String.contains?(uri, "?"), do: "&", else: "?"
    uri <> separator <> URI.encode_query(query)
  end

  defp redirect_error(conn, redirect_uri, state, error, description) do
    query =
      %{"error" => error, "error_description" => description}
      |> maybe_put_state(state)

    redirect(conn, external: append_query(redirect_uri, query))
  end

  defp oauth_error(conn, status, error, description) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: description})
  end
end
