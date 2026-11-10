defmodule IeeeTamuPortal.OIDC do
  @moduledoc """
  Minimal OpenID Connect provider for first-party IEEE TAMU applications.

  The provider implements the authorization code flow with PKCE (S256) and
  RS256-signed ID tokens. Clients are stored in the database and managed from
  the admin UI. Authorization codes and access tokens are signed tokens, so the
  provider does not need any additional tables beyond `oidc_clients`.
  """

  alias IeeeTamuPortal.Accounts.Member
  alias IeeeTamuPortal.OIDC.Clients

  @code_salt "oidc authorization code v1"
  @access_token_salt "oidc access token v1"
  @code_ttl 60
  @access_token_ttl 3_600
  @scopes ~w(openid profile email role)
  @claims ~w(sub iss aud exp iat auth_time nonce name preferred_username email email_verified role)

  @doc "The public issuer URL, e.g. https://portal.ieeetamu.org."
  def issuer, do: config()[:issuer] || IeeeTamuPortalWeb.Endpoint.url()

  @doc "Scopes advertised by discovery."
  def scopes, do: @scopes

  @doc "Claims advertised by discovery."
  def claims, do: @claims

  @doc "Lifetime of an authorization code in seconds."
  def code_ttl, do: @code_ttl

  @doc "Lifetime of an access token in seconds."
  def access_token_ttl, do: @access_token_ttl

  @doc "Registered OIDC clients."
  def clients, do: Clients.list_clients()

  @doc "Look up an enabled client by client_id."
  def get_client(client_id) when is_binary(client_id) do
    Clients.get_enabled_by_client_id(client_id)
  end

  def get_client(_), do: nil

  @doc "Returns true when the redirect URI is registered for the client."
  def redirect_uri_allowed?(client, redirect_uri)
      when is_map(client) and is_binary(redirect_uri) do
    redirect_uri in Clients.redirect_uris(client)
  end

  def redirect_uri_allowed?(_, _), do: false

  @doc "Constant-time comparison of a client secret."
  def client_secret_valid?(client, secret) when is_map(client) and is_binary(secret) do
    Clients.authenticate(client, secret)
  end

  def client_secret_valid?(_, _), do: false

  @doc "Signs a short-lived authorization code."
  def sign_code(claims) do
    Phoenix.Token.sign(IeeeTamuPortalWeb.Endpoint, @code_salt, claims, ttl: @code_ttl)
  end

  @doc "Verifies an authorization code."
  def verify_code(code) when is_binary(code) do
    Phoenix.Token.verify(IeeeTamuPortalWeb.Endpoint, @code_salt, code, max_age: @code_ttl)
  end

  def verify_code(_), do: {:error, :invalid}

  @doc "Signs an opaque access token."
  def sign_access_token(claims) do
    Phoenix.Token.sign(IeeeTamuPortalWeb.Endpoint, @access_token_salt, claims,
      ttl: @access_token_ttl
    )
  end

  @doc "Verifies an opaque access token."
  def verify_access_token(token) when is_binary(token) do
    Phoenix.Token.verify(IeeeTamuPortalWeb.Endpoint, @access_token_salt, token,
      max_age: @access_token_ttl
    )
  end

  def verify_access_token(_), do: {:error, :invalid}

  @doc "Builds a signed RS256 ID token for a member."
  def id_token(%Member{} = member, client_id, nonce, auth_time, scope) do
    now = System.system_time(:second)
    scopes = parse_scope(scope)

    claims = %{
      "iss" => issuer(),
      "sub" => Integer.to_string(member.id),
      "aud" => client_id,
      "exp" => now + @access_token_ttl,
      "iat" => now,
      "auth_time" => auth_time
    }

    claims = maybe_add_profile(claims, member, scopes)
    claims = maybe_add_email(claims, member, scopes)
    claims = maybe_add_role(claims, member, scopes)

    claims =
      if is_binary(nonce) and nonce != "" do
        Map.put(claims, "nonce", nonce)
      else
        claims
      end

    jwk = private_jwk()

    {_, token} =
      JOSE.JWT.sign(jwk, %{"alg" => "RS256", "kid" => kid()}, claims)
      |> JOSE.JWS.compact()

    token
  end

  @doc "Returns the userinfo claims for a member and granted scope."
  def userinfo(%Member{} = member, scope) do
    scopes = parse_scope(scope)

    %{"sub" => Integer.to_string(member.id)}
    |> maybe_add_profile(member, scopes)
    |> maybe_add_email(member, scopes)
    |> maybe_add_role(member, scopes)
  end

  @doc "Returns the public JSON Web Key Set."
  def jwks do
    public = JOSE.JWK.to_public(private_jwk())
    {_, map} = JOSE.JWK.to_map(public)

    key =
      map
      |> Map.put("kid", kid())
      |> Map.put("use", "sig")
      |> Map.put("alg", "RS256")

    %{"keys" => [key]}
  end

  @doc "Human-readable member name, falling back to email."
  def member_name(%Member{} = member) do
    case member.info do
      %{first_name: first_name, last_name: last_name, preferred_name: preferred_name} ->
        name =
          [preferred_name || first_name, last_name]
          |> Enum.reject(&blank?/1)
          |> Enum.join(" ")

        if name == "", do: member.email, else: name

      _ ->
        member.email
    end
  end

  defp maybe_add_profile(claims, member, scopes) do
    if "profile" in scopes do
      Map.merge(claims, %{
        "name" => member_name(member),
        "preferred_username" => member.email
      })
    else
      claims
    end
  end

  defp maybe_add_email(claims, member, scopes) do
    if "email" in scopes do
      Map.merge(claims, %{
        "email" => member.email,
        "email_verified" => not is_nil(member.confirmed_at)
      })
    else
      claims
    end
  end

  defp maybe_add_role(claims, member, scopes) do
    if "role" in scopes do
      Map.put(claims, "role", to_string(member.role))
    else
      claims
    end
  end

  defp parse_scope(scope) when is_binary(scope), do: String.split(scope, " ", trim: true)
  defp parse_scope(_), do: []

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false

  defp config, do: Application.get_env(:ieee_tamu_portal, :oidc, [])

  defp private_jwk do
    case config()[:private_key] do
      nil ->
        generated_jwk()

      "-----BEGIN" <> _ = pem ->
        JOSE.JWK.from_pem(pem)

      path when is_binary(path) ->
        path
        |> File.read!()
        |> JOSE.JWK.from_pem()
    end
  end

  defp generated_jwk do
    case :persistent_term.get({__MODULE__, :generated_jwk}, nil) do
      nil ->
        jwk = JOSE.JWK.generate_key({:rsa, 2048})
        :persistent_term.put({__MODULE__, :generated_jwk}, jwk)
        jwk

      jwk ->
        jwk
    end
  end

  defp kid do
    private_jwk()
    |> JOSE.JWK.to_public()
    |> JOSE.JWK.thumbprint()
  end
end
