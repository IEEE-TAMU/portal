defmodule IeeeTamuPortal.ApiFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `IeeeTamuPortal.Api` context.
  """

  use IeeeTamuPortalWeb.ConnCase

  alias IeeeTamuPortal.Api
  alias IeeeTamuPortal.AccountsFixtures

  def valid_api_key_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test API Key #{System.unique_integer()}",
      "description" => "For testing purposes"
    })
  end

  def admin_api_key_fixture(attrs \\ %{}) do
    {:ok, {token, api_key}} =
      attrs
      |> valid_api_key_attributes()
      |> Api.create_admin_api_key()

    {token, api_key}
  end

  def member_api_key_fixture(member \\ nil, attrs \\ %{}) do
    member = member || AccountsFixtures.member_fixture()

    api_key_attrs =
      attrs
      |> valid_api_key_attributes()
      |> Map.merge(%{"context" => "member", "member_id" => member.id})

    {:ok, {token, api_key}} = Api.create_api_key(api_key_attrs)
    {token, api_key}
  end

  def put_token_header(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
