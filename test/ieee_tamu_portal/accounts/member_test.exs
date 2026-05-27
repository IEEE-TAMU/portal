defmodule IeeeTamuPortal.Accounts.MemberTest do
  use IeeeTamuPortal.DataCase

  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Accounts.Member

  describe "valid_password?/2" do
    test "returns true for correct password" do
      member = member_fixture()

      assert Member.valid_password?(member, valid_member_password())
    end

    test "returns false for incorrect password" do
      member = member_fixture()

      refute Member.valid_password?(member, "wrong_password_")
    end

    test "returns false for nil member" do
      refute Member.valid_password?(nil, "anything")
    end

    test "returns false for empty password" do
      member = member_fixture()

      refute Member.valid_password?(member, "")
    end

    test "returns false when hashed_password is nil" do
      member = %Member{hashed_password: nil, email: "test@tamu.edu"}

      refute Member.valid_password?(member, "anything")
    end
  end

  describe "confirm_changeset/1" do
    test "sets confirmed_at to the current time" do
      member = member_fixture()
      refute member.confirmed_at

      changeset = Member.confirm_changeset(member)
      assert changeset.valid?
      assert get_change(changeset, :confirmed_at)

      confirmed_at = get_change(changeset, :confirmed_at)
      assert %DateTime{} = confirmed_at
      assert DateTime.diff(DateTime.utc_now(), confirmed_at, :second) < 5
    end
  end

  describe "validate_current_password/2" do
    test "adds no error for correct password" do
      member = member_fixture()
      changeset = Ecto.Changeset.cast(member, %{}, [])

      result = Member.validate_current_password(changeset, valid_member_password())

      assert result.valid?
      refute errors_on(result)[:current_password]
    end

    test "adds error for incorrect password" do
      member = member_fixture()
      changeset = Ecto.Changeset.cast(member, %{}, [])

      result = Member.validate_current_password(changeset, "wrong_password")

      assert %{current_password: ["is not valid"]} = errors_on(result)
    end

    test "adds error when member has no hashed_password" do
      member = %Member{hashed_password: nil}
      changeset = Ecto.Changeset.cast(member, %{}, [])

      result = Member.validate_current_password(changeset, "anything")

      assert %{current_password: ["is not valid"]} = errors_on(result)
    end
  end
end
