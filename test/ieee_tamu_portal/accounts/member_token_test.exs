defmodule IeeeTamuPortal.Accounts.MemberTokenTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Accounts.MemberToken
  alias IeeeTamuPortal.Repo

  import IeeeTamuPortal.AccountsFixtures

  @hash_algorithm :sha256
  @rand_size 32

  describe "build_session_token/1" do
    test "returns a binary token and a MemberToken struct with context \"session\"" do
      member = member_fixture()
      {token, member_token} = MemberToken.build_session_token(member)

      assert is_binary(token)
      assert byte_size(token) == @rand_size
      assert member_token.context == "session"
      assert member_token.member_id == member.id
      assert member_token.token == token
    end

    test "token is random on each call" do
      member = member_fixture()
      {t1, _} = MemberToken.build_session_token(member)
      {t2, _} = MemberToken.build_session_token(member)
      refute t1 == t2
    end
  end

  describe "verify_session_token_query/1" do
    test "returns {:ok, query} that finds the member for a valid token" do
      member = member_fixture()
      {token, member_token} = MemberToken.build_session_token(member)
      Repo.insert!(member_token)

      assert {:ok, query} = MemberToken.verify_session_token_query(token)
      assert %{id: member_id} = Repo.one(query)
      assert member_id == member.id
    end

    test "returns {:ok, query} that returns nil for an unknown token" do
      token = :crypto.strong_rand_bytes(@rand_size)

      assert {:ok, query} = MemberToken.verify_session_token_query(token)
      assert is_nil(Repo.one(query))
    end

    test "returns nil for an expired token" do
      member = member_fixture()
      {token, member_token} = MemberToken.build_session_token(member)
      member_token = Repo.insert!(member_token)

      Repo.update_all(
        from(t in MemberToken, where: t.id == ^member_token.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      assert {:ok, query} = MemberToken.verify_session_token_query(token)
      assert is_nil(Repo.one(query))
    end
  end

  describe "build_email_token/2" do
    test "returns a base64url-encoded token and a MemberToken struct" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")

      assert is_binary(encoded_token)
      assert String.length(encoded_token) > 0

      {:ok, decoded} = Base.url_decode64(encoded_token, padding: false)
      assert byte_size(decoded) == @rand_size

      assert member_token.context == "confirm"
      assert member_token.sent_to == member.email
      assert member_token.member_id == member.id

      expected_hash = :crypto.hash(@hash_algorithm, decoded)
      assert member_token.token == expected_hash
    end

    test "supports reset_password context" do
      member = member_fixture()
      {_encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
      assert member_token.context == "reset_password"
      assert member_token.sent_to == member.email
    end

    test "token is random on each call" do
      member = member_fixture()
      {t1, _} = MemberToken.build_email_token(member, "confirm")
      {t2, _} = MemberToken.build_email_token(member, "confirm")
      assert t1 != t2
    end
  end

  describe "verify_email_token_query/2" do
    test "returns {:ok, query} that finds the member for a valid confirm token" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)

      assert {:ok, query} = MemberToken.verify_email_token_query(encoded_token, "confirm")
      assert %{id: member_id} = Repo.one(query)
      assert member_id == member.id
    end

    test "returns {:ok, query} that finds the member for a valid reset_password token" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
      Repo.insert!(member_token)

      assert {:ok, query} =
               MemberToken.verify_email_token_query(encoded_token, "reset_password")

      assert %{id: member_id} = Repo.one(query)
      assert member_id == member.id
    end

    test "returns :error for invalid base64 token" do
      assert MemberToken.verify_email_token_query("!!!not_base64!!!", "confirm") == :error
    end

    test "returns {:ok, query} that returns nil for wrong context" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)

      assert {:ok, query} =
               MemberToken.verify_email_token_query(encoded_token, "reset_password")

      assert is_nil(Repo.one(query))
    end

    test "returns {:ok, query} that returns nil when email has changed" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)

      # Change the member's email after token was created
      Repo.update_all(
        from(m in IeeeTamuPortal.Accounts.Member, where: m.id == ^member.id),
        set: [email: "changed@tamu.edu"]
      )

      assert {:ok, query} = MemberToken.verify_email_token_query(encoded_token, "confirm")
      assert is_nil(Repo.one(query))
    end

    test "returns {:ok, query} that returns nil for expired confirm token" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      member_token = Repo.insert!(member_token)

      Repo.update_all(
        from(t in MemberToken, where: t.id == ^member_token.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      assert {:ok, query} = MemberToken.verify_email_token_query(encoded_token, "confirm")
      assert is_nil(Repo.one(query))
    end

    test "returns {:ok, query} that returns nil for expired reset_password token" do
      member = member_fixture()
      {encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
      member_token = Repo.insert!(member_token)

      # Reset password tokens have 1-day validity; expire by setting far back
      Repo.update_all(
        from(t in MemberToken, where: t.id == ^member_token.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      assert {:ok, query} =
               MemberToken.verify_email_token_query(encoded_token, "reset_password")

      assert is_nil(Repo.one(query))
    end
  end

  describe "verify_change_email_token_query/2" do
    test "returns {:ok, query} that finds the token for a valid change: context" do
      member = member_fixture()
      context = "change:#{member.email}"
      {encoded_token, member_token} = MemberToken.build_email_token(member, context)
      Repo.insert!(member_token)

      assert {:ok, query} = MemberToken.verify_change_email_token_query(encoded_token, context)
      assert %MemberToken{} = Repo.one(query)
    end

    test "returns {:ok, query} that returns nil for expired token" do
      member = member_fixture()
      context = "change:#{member.email}"
      {encoded_token, member_token} = MemberToken.build_email_token(member, context)
      member_token = Repo.insert!(member_token)

      Repo.update_all(
        from(t in MemberToken, where: t.id == ^member_token.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      assert {:ok, query} = MemberToken.verify_change_email_token_query(encoded_token, context)
      assert is_nil(Repo.one(query))
    end

    test "returns :error for invalid base64 token" do
      assert MemberToken.verify_change_email_token_query("!!!bad!!!", "change:foo@tamu.edu") ==
               :error
    end

    test "does not check that email has not changed (different from verify_email_token_query)" do
      member = member_fixture()
      context = "change:#{member.email}"
      {encoded_token, member_token} = MemberToken.build_email_token(member, context)
      Repo.insert!(member_token)

      # Change the member's email — this should NOT invalidate the change token
      Repo.update_all(
        from(m in IeeeTamuPortal.Accounts.Member, where: m.id == ^member.id),
        set: [email: "changed@tamu.edu"]
      )

      assert {:ok, query} = MemberToken.verify_change_email_token_query(encoded_token, context)
      assert %MemberToken{} = Repo.one(query)
    end
  end

  describe "by_token_and_context_query/2" do
    test "returns a query that matches a specific token and context" do
      member = member_fixture()
      {_, member_token} = MemberToken.build_email_token(member, "confirm")
      inserted = Repo.insert!(member_token)

      query = MemberToken.by_token_and_context_query(member_token.token, "confirm")
      assert %MemberToken{id: token_id} = Repo.one(query)
      assert token_id == inserted.id
    end

    test "returns a query that does not match wrong context" do
      member = member_fixture()
      {_, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)

      query = MemberToken.by_token_and_context_query(member_token.token, "reset_password")
      assert is_nil(Repo.one(query))
    end
  end

  describe "by_member_and_contexts_query/2" do
    test "with :all returns a query matching all tokens for the member" do
      member = member_fixture()
      {_, t1} = MemberToken.build_email_token(member, "confirm")
      {_, t2} = MemberToken.build_email_token(member, "reset_password")
      Repo.insert!(t1)
      Repo.insert!(t2)

      query = MemberToken.by_member_and_contexts_query(member, :all)
      results = Repo.all(query)
      assert length(results) == 2
    end

    test "with a list of contexts returns only tokens matching those contexts" do
      member = member_fixture()
      {_, t1} = MemberToken.build_email_token(member, "confirm")
      {_, t2} = MemberToken.build_email_token(member, "reset_password")
      Repo.insert!(t1)
      Repo.insert!(t2)

      query = MemberToken.by_member_and_contexts_query(member, ["confirm"])
      results = Repo.all(query)
      assert length(results) == 1
      assert hd(results).context == "confirm"
    end

    test "returns empty list when member has no tokens" do
      member = member_fixture()

      query = MemberToken.by_member_and_contexts_query(member, :all)
      assert Repo.all(query) == []
    end
  end
end
