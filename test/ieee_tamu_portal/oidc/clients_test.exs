defmodule IeeeTamuPortal.OIDC.ClientsTest do
  use IeeeTamuPortal.DataCase, async: false

  import IeeeTamuPortal.OIDCFixtures

  alias IeeeTamuPortal.AccountsFixtures
  alias IeeeTamuPortal.OIDC.Client
  alias IeeeTamuPortal.OIDC.Clients

  setup do
    Repo.delete_all(Client)
    :ok
  end

  test "creates a client and stores only a hash of the secret" do
    {client, secret} = oidc_client_fixture()

    assert is_binary(client.client_secret_hash)
    refute client.client_secret_hash == secret
    assert client.secret_prefix == String.slice(secret, 0, 16)
    assert Clients.authenticate(client, secret)
    refute Clients.authenticate(client, "wrong-secret")
  end

  test "rotates the secret and invalidates the old one" do
    {client, old_secret} = oidc_client_fixture()

    assert {:ok, {client, new_secret}} = Clients.rotate_secret(client)
    refute Clients.authenticate(client, old_secret)
    assert Clients.authenticate(client, new_secret)
  end

  test "disabled clients are hidden from the provider but visible to admins" do
    {client, _secret} = oidc_client_fixture()

    assert Clients.get_enabled_by_client_id(client.client_id)

    assert {:ok, _client} = Clients.update_client(client, %{"enabled" => false})
    refute Clients.get_enabled_by_client_id(client.client_id)
    assert Clients.get_by_client_id(client.client_id)
  end

  test "parses redirect URIs and scopes" do
    {client, _secret} =
      oidc_client_fixture(%{
        "redirect_uris" => "https://a.example/cb\nhttps://b.example/cb",
        "scopes" => "openid profile"
      })

    assert Clients.redirect_uris(client) == [
             "https://a.example/cb",
             "https://b.example/cb"
           ]

    assert Clients.scopes(client) == ["openid", "profile"]
  end

  test "rejects insecure redirect URIs that are not localhost" do
    admin = AccountsFixtures.admin_member_fixture()

    assert {:error, changeset} =
             Clients.create_client(
               %{
                 "name" => "Bad Redirect",
                 "client_id" => "bad-redirect",
                 "redirect_uris" => "http://example.com/cb",
                 "scopes" => "openid"
               },
               admin
             )

    assert changeset.errors[:redirect_uris]
  end

  test "rejects scopes that do not include openid" do
    admin = AccountsFixtures.admin_member_fixture()

    assert {:error, changeset} =
             Clients.create_client(
               %{
                 "name" => "Bad Scope",
                 "client_id" => "bad-scope",
                 "redirect_uris" => "https://example.com/cb",
                 "scopes" => "profile"
               },
               admin
             )

    assert changeset.errors[:scopes]
  end

  test "marks last_used_at" do
    {client, _secret} = oidc_client_fixture()

    assert is_nil(client.last_used_at)
    assert {:ok, client} = Clients.mark_used(client)
    assert client.last_used_at
  end
end
