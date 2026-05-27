defmodule IeeeTamuPortal.AccountsTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Accounts

  import IeeeTamuPortal.AccountsFixtures
  alias IeeeTamuPortal.Accounts.{Member, MemberToken}

  describe "get_member_by_email/1" do
    test "does not return the member if the email does not exist" do
      refute Accounts.get_member_by_email("unknown@example.com")
    end

    test "returns the member if the email exists" do
      %{id: id} = member = member_fixture()
      assert %Member{id: ^id} = Accounts.get_member_by_email(member.email)
    end
  end

  describe "get_member_by_email_and_password/2" do
    test "does not return the member if the email does not exist" do
      refute Accounts.get_member_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the member if the password is not valid" do
      member = member_fixture()
      refute Accounts.get_member_by_email_and_password(member.email, "invalid")
    end

    test "returns the member if the email and password are valid" do
      %{id: id} = member = member_fixture()

      assert %Member{id: ^id} =
               Accounts.get_member_by_email_and_password(member.email, valid_member_password())
    end
  end

  describe "get_member!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_member!(-1)
      end
    end

    test "returns the member with the given id" do
      %{id: id} = member = member_fixture()
      assert %Member{id: ^id} = Accounts.get_member!(member.id)
    end
  end

  describe "register_member/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_member(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_member(%{email: "not valid", password: "invalid"})

      assert %{
               email: ["must be a TAMU email", "must be a valid email"],
               password: ["should be at least 8 character(s)"]
             } = errors_on(changeset)
    end

    test "validates email to be a TAMU email" do
      {:error, changeset} =
        Accounts.register_member(%{email: "test@example.com", password: "not valid"})

      assert %{
               email: ["must be a TAMU email"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_member(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = member_fixture()
      {:error, changeset} = Accounts.register_member(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_member(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers members with a hashed password" do
      email = unique_member_email()
      {:ok, member} = Accounts.register_member(valid_member_attributes(email: email))
      assert member.email == email
      assert is_binary(member.hashed_password)
      assert is_nil(member.confirmed_at)
      assert is_nil(member.password)
    end
  end

  describe "change_member_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_member_registration(%Member{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_member_email()
      password = valid_member_password()

      changeset =
        Accounts.change_member_registration(
          %Member{},
          valid_member_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_member_email/2" do
    test "returns a member changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_member_email(%Member{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_member_email/3" do
    setup do
      %{member: member_fixture()}
    end

    test "requires email to change", %{member: member} do
      {:error, changeset} = Accounts.apply_member_email(member, valid_member_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{member: member} do
      {:error, changeset} =
        Accounts.apply_member_email(member, valid_member_password(), %{email: "not valid"})

      assert %{email: ["must be a TAMU email", "must be a valid email"]} =
               errors_on(changeset)
    end

    test "validates TAMU email", %{member: member} do
      {:error, changeset} =
        Accounts.apply_member_email(member, valid_member_password(), %{email: "test@eexample.com"})

      assert %{email: ["must be a TAMU email"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{member: member} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_member_email(member, valid_member_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{member: member} do
      %{email: email} = member_fixture()
      password = valid_member_password()

      {:error, changeset} = Accounts.apply_member_email(member, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{member: member} do
      {:error, changeset} =
        Accounts.apply_member_email(member, "invalid", %{email: unique_member_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{member: member} do
      email = unique_member_email()

      {:ok, member} =
        Accounts.apply_member_email(member, valid_member_password(), %{email: email})

      assert member.email == email
      assert Accounts.get_member!(member.id).email != email
    end
  end

  describe "change_member_password/2" do
    test "returns a member changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_member_password(%Member{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_member_password(%Member{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_member_password/3" do
    setup do
      %{member: member_fixture()}
    end

    test "validates password", %{member: member} do
      {:error, changeset} =
        Accounts.update_member_password(member, valid_member_password(), %{
          password: "invalid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 8 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{member: member} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_member_password(member, valid_member_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{member: member} do
      {:error, changeset} =
        Accounts.update_member_password(member, "invalid", %{password: valid_member_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{member: member} do
      {:ok, member} =
        Accounts.update_member_password(member, valid_member_password(), %{
          password: "new valid password"
        })

      assert is_nil(member.password)
      assert Accounts.get_member_by_email_and_password(member.email, "new valid password")
    end

    test "deletes all tokens for the given member", %{member: member} do
      _ = Accounts.generate_member_session_token(member)

      {:ok, _} =
        Accounts.update_member_password(member, valid_member_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(MemberToken, member_id: member.id)
    end
  end

  describe "generate_member_session_token/1" do
    setup do
      %{member: member_fixture()}
    end

    test "generates a token", %{member: member} do
      token = Accounts.generate_member_session_token(member)
      assert member_token = Repo.get_by(MemberToken, token: token)
      assert member_token.context == "session"

      # Creating the same token for another member should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%MemberToken{
          token: member_token.token,
          member_id: member_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_member_by_session_token/1" do
    setup do
      member = member_fixture()
      token = Accounts.generate_member_session_token(member)
      %{member: member, token: token}
    end

    test "returns member by token", %{member: member, token: token} do
      assert session_member = Accounts.get_member_by_session_token(token)
      assert session_member.id == member.id
    end

    test "does not return member for invalid token" do
      refute Accounts.get_member_by_session_token("oops")
    end

    test "does not return member for expired token", %{token: token} do
      {1, nil} = Repo.update_all(MemberToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_member_by_session_token(token)
    end
  end

  describe "delete_member_session_token/1" do
    test "deletes the token" do
      member = member_fixture()
      token = Accounts.generate_member_session_token(member)
      assert Accounts.delete_member_session_token(token) == :ok
      refute Accounts.get_member_by_session_token(token)
    end
  end

  describe "deliver_member_confirmation_instructions/2" do
    setup do
      %{member: member_fixture()}
    end

    test "sends token through notification", %{member: member} do
      token =
        extract_member_token(fn url ->
          Accounts.deliver_member_confirmation_instructions(member, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert member_token = Repo.get_by(MemberToken, token: :crypto.hash(:sha256, token))
      assert member_token.member_id == member.id
      assert member_token.sent_to == member.email
      assert member_token.context == "confirm"
    end
  end

  describe "confirm_member/1" do
    setup do
      member = member_fixture()

      token =
        extract_member_token(fn url ->
          Accounts.deliver_member_confirmation_instructions(member, url)
        end)

      %{member: member, token: token}
    end

    test "confirms the email with a valid token", %{member: member, token: token} do
      assert {:ok, confirmed_member} = Accounts.confirm_member(token)
      assert confirmed_member.confirmed_at
      assert confirmed_member.confirmed_at != member.confirmed_at
      assert Repo.get!(Member, member.id).confirmed_at
      refute Repo.get_by(MemberToken, member_id: member.id)
    end

    test "does not confirm with invalid token", %{member: member} do
      assert Accounts.confirm_member("oops") == :error
      refute Repo.get!(Member, member.id).confirmed_at
      assert Repo.get_by(MemberToken, member_id: member.id)
    end

    test "does not confirm email if token expired", %{member: member, token: token} do
      {1, nil} = Repo.update_all(MemberToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_member(token) == :error
      refute Repo.get!(Member, member.id).confirmed_at
      assert Repo.get_by(MemberToken, member_id: member.id)
    end
  end

  describe "deliver_member_reset_password_instructions/2" do
    setup do
      %{member: member_fixture()}
    end

    test "sends token through notification", %{member: member} do
      token =
        extract_member_token(fn url ->
          Accounts.deliver_member_reset_password_instructions(member, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert member_token = Repo.get_by(MemberToken, token: :crypto.hash(:sha256, token))
      assert member_token.member_id == member.id
      assert member_token.sent_to == member.email
      assert member_token.context == "reset_password"
    end
  end

  describe "get_member_by_reset_password_token/1" do
    setup do
      member = member_fixture()

      token =
        extract_member_token(fn url ->
          Accounts.deliver_member_reset_password_instructions(member, url)
        end)

      %{member: member, token: token}
    end

    test "returns the member with valid token", %{member: %{id: id}, token: token} do
      assert %Member{id: ^id} = Accounts.get_member_by_reset_password_token(token)
      assert Repo.get_by(MemberToken, member_id: id)
    end

    test "does not return the member with invalid token", %{member: member} do
      refute Accounts.get_member_by_reset_password_token("oops")
      assert Repo.get_by(MemberToken, member_id: member.id)
    end

    test "does not return the member if token expired", %{member: member, token: token} do
      {1, nil} = Repo.update_all(MemberToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_member_by_reset_password_token(token)
      assert Repo.get_by(MemberToken, member_id: member.id)
    end
  end

  describe "reset_member_password/2" do
    setup do
      %{member: member_fixture()}
    end

    test "validates password", %{member: member} do
      {:error, changeset} =
        Accounts.reset_member_password(member, %{
          password: "invalid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 8 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{member: member} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_member_password(member, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{member: member} do
      {:ok, updated_member} =
        Accounts.reset_member_password(member, %{password: "new valid password"})

      assert is_nil(updated_member.password)
      assert Accounts.get_member_by_email_and_password(member.email, "new valid password")
    end

    test "deletes all tokens for the given member", %{member: member} do
      _ = Accounts.generate_member_session_token(member)
      {:ok, _} = Accounts.reset_member_password(member, %{password: "new valid password"})
      refute Repo.get_by(MemberToken, member_id: member.id)
    end
  end

  describe "inspect/2 for the Member module" do
    test "does not include password" do
      refute inspect(%Member{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "link_auth_method/2" do
    test "creates an auth method for a member" do
      member = member_fixture()

      assert {:ok, %IeeeTamuPortal.Accounts.AuthMethod{} = auth} =
               Accounts.link_auth_method(member, %{provider: :discord, sub: "123456"})

      assert auth.member_id == member.id
      assert auth.provider == :discord
      assert auth.sub == "123456"
    end

    test "validates required provider and sub" do
      member = member_fixture()

      {:error, changeset} = Accounts.link_auth_method(member, %{})

      assert %{provider: ["can't be blank"], sub: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique constraint on provider + sub across members" do
      m1 = member_fixture()
      m2 = member_fixture()

      {:ok, _} = Accounts.link_auth_method(m1, %{provider: :discord, sub: "same-sub"})

      # Different member, same provider + sub = unique_index violation
      assert {:error, changeset} =
               Accounts.link_auth_method(m2, %{provider: :discord, sub: "same-sub"})

      assert errors_on(changeset)[:provider]
    end

    test "enforces primary key constraint on provider + member_id" do
      member = member_fixture()

      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "first"})

      # Same member + same provider = primary key violation (not caught by changeset)
      assert_raise Ecto.ConstraintError, fn ->
        Accounts.link_auth_method(member, %{provider: :discord, sub: "second"})
      end
    end

    test "stores optional preferred_username and email" do
      member = member_fixture()

      {:ok, auth} =
        Accounts.link_auth_method(member, %{
          provider: :google,
          sub: "g-sub",
          preferred_username: "jdoe",
          email: "jdoe@gmail.com",
          email_verified: true
        })

      assert auth.preferred_username == "jdoe"
      assert auth.email == "jdoe@gmail.com"
      assert auth.email_verified
    end
  end

  describe "get_auth_method/2" do
    test "returns the auth method for the given member and provider" do
      member = member_fixture()
      {:ok, created} = Accounts.link_auth_method(member, %{provider: :discord, sub: "abc"})

      assert %IeeeTamuPortal.Accounts.AuthMethod{} =
               auth =
               Accounts.get_auth_method(member, :discord)

      assert auth.member_id == member.id
      assert auth.sub == created.sub
    end

    test "returns nil if no auth method exists" do
      member = member_fixture()
      assert is_nil(Accounts.get_auth_method(member, :discord))
    end

    test "returns nil for wrong provider with existing method" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "abc"})

      assert is_nil(Accounts.get_auth_method(member, :google))
    end
  end

  describe "list_auth_methods/1" do
    test "returns empty list when member has no auth methods" do
      member = member_fixture()
      assert Accounts.list_auth_methods(member) == []
    end

    test "returns all auth methods for a member" do
      member = member_fixture()

      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "d-sub"})
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :google, sub: "g-sub"})

      methods = Accounts.list_auth_methods(member)
      assert length(methods) == 2
    end

    test "returns only the member's auth methods, not other members'" do
      m1 = member_fixture()
      m2 = member_fixture()

      {:ok, _} = Accounts.link_auth_method(m1, %{provider: :discord, sub: "m1-sub"})
      {:ok, _} = Accounts.link_auth_method(m2, %{provider: :discord, sub: "m2-sub"})

      assert length(Accounts.list_auth_methods(m1)) == 1
    end
  end

  describe "unlink_auth_method/2" do
    test "deletes an existing auth method" do
      member = member_fixture()
      {:ok, _created} = Accounts.link_auth_method(member, %{provider: :discord, sub: "sub"})

      assert {:ok, _deleted} = Accounts.unlink_auth_method(member, :discord)
      assert is_nil(Accounts.get_auth_method(member, :discord))
    end

    test "returns {:error, :not_found} when no auth method exists" do
      member = member_fixture()
      assert Accounts.unlink_auth_method(member, :discord) == {:error, :not_found}
    end

    test "returns {:error, :not_found} for wrong provider" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "sub"})

      assert Accounts.unlink_auth_method(member, :google) == {:error, :not_found}
    end
  end

  describe "get_member_by_auth_sub/2" do
    test "returns the member for a known provider + sub" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "discord-sub-123"})

      assert %Member{id: member_id} = Accounts.get_member_by_auth_sub(:discord, "discord-sub-123")
      assert member_id == member.id
    end

    test "returns nil for unknown sub" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "known-sub"})

      assert is_nil(Accounts.get_member_by_auth_sub(:discord, "unknown-sub"))
    end

    test "returns nil for unknown provider with known sub" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "sub-1"})

      assert is_nil(Accounts.get_member_by_auth_sub(:google, "sub-1"))
    end
  end

  describe "preload_member_auth_methods/1" do
    test "preloads the secondary_auth_methods association" do
      member = member_fixture()
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :discord, sub: "sub-1"})
      {:ok, _} = Accounts.link_auth_method(member, %{provider: :google, sub: "sub-2"})

      preloaded = Accounts.preload_member_auth_methods(member)
      assert length(preloaded.secondary_auth_methods) == 2
    end

    test "returns empty list when no auth methods exist" do
      member = member_fixture()

      preloaded = Accounts.preload_member_auth_methods(member)
      assert preloaded.secondary_auth_methods == []
    end
  end

  ## Database getters

  describe "count_members/0" do
    test "returns 0 with no members" do
      assert Accounts.count_members() == 0
    end

    test "returns the count of members" do
      member_fixture()
      member_fixture()
      assert Accounts.count_members() == 2
    end
  end

  describe "list_members/0" do
    test "returns empty list with no members" do
      assert Accounts.list_members() == []
    end

    test "returns all members with resumes preloaded" do
      m1 = member_fixture()
      m2 = member_fixture()

      members = Accounts.list_members()
      ids = Enum.map(members, & &1.id)
      assert length(members) == 2
      assert m1.id in ids
      assert m2.id in ids
    end
  end

  describe "get_member/1" do
    test "returns member by id" do
      %{id: id} = _member = member_fixture()
      assert %Member{id: ^id} = Accounts.get_member(id)
    end

    test "returns nil for nonexistent id" do
      assert is_nil(Accounts.get_member(-1))
    end
  end

  describe "get_member_with_info/1" do
    test "returns member with info preloaded" do
      member = member_fixture()

      result = Accounts.get_member_with_info(member.id)
      assert result.id == member.id
      assert is_nil(result.info)
    end

    test "returns nil for nonexistent id" do
      assert is_nil(Accounts.get_member_with_info(-1))
    end
  end

  describe "get_all_members_with_info/0" do
    test "returns all members with info association preloaded" do
      member_fixture()
      member_fixture()

      members = Accounts.get_all_members_with_info()
      assert length(members) == 2
    end

    test "returns empty list when no members" do
      assert Accounts.get_all_members_with_info() == []
    end
  end

  describe "list_members_with_registrations/1" do
    import IeeeTamuPortal.MembersFixtures

    test "returns members with filtered registrations for a given year" do
      member = member_fixture()
      _registration = registration_fixture(member, %{year: 2024})

      results = Accounts.list_members_with_registrations(2024)
      assert length(results) >= 1

      found = Enum.find(results, &(&1.id == member.id))
      assert found
      assert length(found.registrations) == 1
    end

    test "filters out registrations from other years" do
      member = member_fixture()

      registration_fixture(member, %{year: 2023})
      # Use a different member for 2025 to avoid confirmation_code collision
      m2 = member_fixture()
      _registration_2025 = registration_fixture(m2, %{year: 2025})

      results = Accounts.list_members_with_registrations(2024)
      found = Enum.find(results, &(&1.id == member.id))

      assert found
      assert found.registrations == []
    end
  end

  ## Confirmation edge cases

  describe "deliver_member_confirmation_instructions/2 already_confirmed" do
    test "returns {:error, :already_confirmed} for confirmed member" do
      member = confirmed_member_fixture()

      assert {:error, :already_confirmed} =
               Accounts.deliver_member_confirmation_instructions(member, fn _ -> "url" end)
    end
  end

  ## Email update

  describe "update_member_email/2" do
    test "updates member email with valid change token" do
      member = member_fixture()
      new_email = unique_member_email()
      context = "change:#{member.email}"

      # Manually build the token — sent_to must be the NEW email
      raw_token = :crypto.strong_rand_bytes(32)
      hashed_token = :crypto.hash(:sha256, raw_token)
      encoded_token = Base.url_encode64(raw_token, padding: false)

      Repo.insert!(%MemberToken{
        token: hashed_token,
        context: context,
        sent_to: new_email,
        member_id: member.id
      })

      assert Accounts.update_member_email(member, encoded_token) == :ok

      updated = Accounts.get_member!(member.id)
      assert updated.email == new_email
      assert updated.confirmed_at

      # Tokens for this context should be deleted
      refute Repo.get_by(MemberToken, member_id: member.id, context: context)
    end

    test "returns :error with invalid token" do
      member = member_fixture()

      assert Accounts.update_member_email(member, "badtoken") == :error
    end

    test "returns :error with expired token" do
      member = member_fixture()
      context = "change:#{member.email}"

      {encoded_token, member_token} = MemberToken.build_email_token(member, context)
      member_token = Repo.insert!(member_token)

      Repo.update_all(
        from(t in MemberToken, where: t.id == ^member_token.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      assert Accounts.update_member_email(member, encoded_token) == :error
    end
  end

  ## Preload helpers

  describe "preload_member_info/1" do
    test "preloads the info association" do
      member = member_fixture()

      preloaded = Accounts.preload_member_info(member)
      assert is_nil(preloaded.info)
    end
  end

  describe "preload_member_resume/1" do
    test "preloads the resume association" do
      member = member_fixture()

      preloaded = Accounts.preload_member_resume(member)
      assert is_nil(preloaded.resume)
    end
  end

  describe "list_members_paginated/1" do
    import IeeeTamuPortal.MembersFixtures

    test "returns paginated members with empty params" do
      member_fixture()
      member_fixture()

      {members, meta} = Accounts.list_members_paginated(%{})

      assert length(members) == 2
      assert is_map(meta)
      assert meta.total_count == 2
    end

    test "returns empty when no members" do
      {members, meta} = Accounts.list_members_paginated(%{})

      assert members == []
      assert meta.total_count == 0
    end
  end
end
