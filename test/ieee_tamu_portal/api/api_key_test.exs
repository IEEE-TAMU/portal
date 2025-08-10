defmodule IeeeTamuPortal.Api.ApiKeyTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Api.ApiKey
  alias IeeeTamuPortal.Repo

  import IeeeTamuPortal.AccountsFixtures

  describe "build_api_key/1" do
    test "generates token and changeset with valid attrs" do
      attrs = %{name: "Test API Key", context: :admin}

      {plain_token, changeset} = ApiKey.build_api_key(attrs)

      assert String.starts_with?(plain_token, "portal_api_")
      assert String.length(plain_token) > 20
      assert changeset.valid?
      assert changeset.changes[:name] == "Test API Key"
      assert changeset.changes[:context] == :admin
      assert changeset.changes[:token_hash]
      assert changeset.changes[:prefix] == String.slice(plain_token, 0, 20)
    end

    test "generates different tokens each time" do
      attrs = %{name: "Test API Key", context: :admin}

      {token1, _} = ApiKey.build_api_key(attrs)
      {token2, _} = ApiKey.build_api_key(attrs)

      assert token1 != token2
    end

    test "validates required fields" do
      {_, changeset} = ApiKey.build_api_key(%{})

      refute changeset.valid?
      assert changeset.errors[:name]
      assert changeset.errors[:context]
    end

    test "validates name length" do
      long_name = String.duplicate("a", 101)
      {_, changeset} = ApiKey.build_api_key(%{name: long_name, context: :admin})

      refute changeset.valid?
      assert changeset.errors[:name]
    end

    test "validates context inclusion" do
      {_, changeset} = ApiKey.build_api_key(%{name: "Test", context: :invalid})

      refute changeset.valid?
      assert changeset.errors[:context]
    end

    test "works with member context and member_id" do
      member = member_fixture()
      attrs = %{name: "Member API Key", context: :member, member_id: member.id}

      {plain_token, changeset} = ApiKey.build_api_key(attrs)

      assert changeset.valid?
      assert changeset.changes[:context] == :member
      assert changeset.changes[:member_id] == member.id
      assert String.starts_with?(plain_token, "portal_api_")
    end
  end

  describe "verify_token/1" do
    test "finds active API key with valid token" do
      attrs = %{name: "Test API Key", context: :admin}
      {plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      query = ApiKey.verify_token(plain_token)
      result = Repo.one(query)

      assert result.id == api_key.id
      assert result.name == "Test API Key"
      assert result.context == :admin
    end

    test "does not find inactive API key" do
      attrs = %{name: "Test API Key", context: :admin}
      {plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      # Deactivate the API key
      api_key
      |> ApiKey.changeset(%{is_active: false})
      |> Repo.update!()

      query = ApiKey.verify_token(plain_token)
      result = Repo.one(query)

      assert result == nil
    end

    test "does not find API key with invalid token" do
      attrs = %{name: "Test API Key", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      Repo.insert(changeset)

      query = ApiKey.verify_token("invalid_token")
      result = Repo.one(query)

      assert result == nil
    end
  end

  describe "touch_last_used/1" do
    test "updates last_used_at timestamp" do
      attrs = %{name: "Test API Key", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      # Initially last_used_at should be nil
      assert api_key.last_used_at == nil

      updated_changeset = ApiKey.touch_last_used(api_key)
      {:ok, updated_api_key} = Repo.update(updated_changeset)

      assert updated_api_key.last_used_at
      assert DateTime.diff(updated_api_key.last_used_at, DateTime.utc_now(), :second) <= 1
    end
  end

  describe "changeset/2" do
    test "validates and updates api key attributes" do
      attrs = %{name: "Original Name", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      update_attrs = %{name: "Updated Name", is_active: false}
      update_changeset = ApiKey.changeset(api_key, update_attrs)

      assert update_changeset.valid?
      assert update_changeset.changes[:name] == "Updated Name"
      assert update_changeset.changes[:is_active] == false
    end

    test "validates required fields on update" do
      attrs = %{name: "Test API Key", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      update_changeset = ApiKey.changeset(api_key, %{name: ""})

      refute update_changeset.valid?
      assert update_changeset.errors[:name]
    end

    test "validates name length on update" do
      attrs = %{name: "Test API Key", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      long_name = String.duplicate("a", 101)
      update_changeset = ApiKey.changeset(api_key, %{name: long_name})

      refute update_changeset.valid?
      assert update_changeset.errors[:name]
    end

    test "validates context inclusion on update" do
      attrs = %{name: "Test API Key", context: :admin}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      update_changeset = ApiKey.changeset(api_key, %{context: :invalid})

      refute update_changeset.valid?
      assert update_changeset.errors[:context]
    end

    test "allows updating member_id for member context" do
      member = member_fixture()
      attrs = %{name: "Member API Key", context: :member}
      {_plain_token, changeset} = ApiKey.build_api_key(attrs)
      {:ok, api_key} = Repo.insert(changeset)

      update_changeset = ApiKey.changeset(api_key, %{member_id: member.id})

      assert update_changeset.valid?
      assert update_changeset.changes[:member_id] == member.id
    end
  end
end
