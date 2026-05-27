defmodule IeeeTamuPortal.Accounts.MemberNotifierTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Accounts.MemberNotifier

  import IeeeTamuPortal.AccountsFixtures

  describe "deliver_confirmation_instructions/2" do
    test "sends an email with confirmation instructions" do
      member = member_fixture()
      url = "http://localhost/members/confirm/test-token"

      {:ok, email} = MemberNotifier.deliver_confirmation_instructions(member, url)

      assert email.to == [{"", member.email}]
      assert email.from == {"IEEE TAMU Portal", "portal@ieeetamu.org"}
      assert email.subject == "Confirmation instructions"
      assert email.text_body =~ "confirm your account"
      assert email.text_body =~ url
    end
  end

  describe "deliver_reset_password_instructions/2" do
    test "sends an email with reset password instructions" do
      member = member_fixture()
      url = "http://localhost/members/reset_password/test-token"

      {:ok, email} = MemberNotifier.deliver_reset_password_instructions(member, url)

      assert email.to == [{"", member.email}]
      assert email.from == {"IEEE TAMU Portal", "portal@ieeetamu.org"}
      assert email.subject == "Reset password instructions"
      assert email.text_body =~ "reset your password"
      assert email.text_body =~ url
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "sends an email with email change instructions" do
      member = member_fixture()
      url = "http://localhost/members/settings/confirm_email/test-token"

      {:ok, email} = MemberNotifier.deliver_update_email_instructions(member, url)

      assert email.to == [{"", member.email}]
      assert email.from == {"IEEE TAMU Portal", "portal@ieeetamu.org"}
      assert email.subject == "Update email instructions"
      assert email.text_body =~ "change your email"
      assert email.text_body =~ url
    end
  end
end
