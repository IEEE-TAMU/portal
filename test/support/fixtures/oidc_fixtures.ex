defmodule IeeeTamuPortal.OIDCFixtures do
  @moduledoc false

  alias IeeeTamuPortal.AccountsFixtures
  alias IeeeTamuPortal.OIDC.Clients

  def oidc_client_fixture(attrs \\ %{}) do
    admin = AccountsFixtures.admin_member_fixture()

    attrs =
      Enum.into(attrs, %{
        "name" => "Test Client #{System.unique_integer([:positive])}",
        "client_id" => "test-client-#{System.unique_integer([:positive])}",
        "redirect_uris" => "http://localhost:3000/api/auth/callback",
        "scopes" => "openid profile email role",
        "enabled" => true
      })

    {:ok, {client, secret}} = Clients.create_client(attrs, admin)
    {client, secret}
  end
end
