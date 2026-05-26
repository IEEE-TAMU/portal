defmodule IeeeTamuPortal.MembersTest do
  use IeeeTamuPortal.DataCase

  alias IeeeTamuPortal.Members

  describe "valid_tamu_email?/1" do
    test "accepts valid tamu.edu emails" do
      assert Members.valid_tamu_email?("user@tamu.edu")
    end

    test "accepts valid tamut.edu emails" do
      assert Members.valid_tamu_email?("user@tamut.edu")
    end

    test "accepts emails with @ace.tamut.edu subdomain" do
      assert Members.valid_tamu_email?("user@ace.tamut.edu")
    end

    test "accepts uppercase TAMU.EDU domain" do
      assert Members.valid_tamu_email?("user@TAMU.EDU")
    end

    test "accepts mixed-case TAMU domain" do
      assert Members.valid_tamu_email?("user@Tamu.Edu")
    end

    test "accepts uppercase TAMUT.EDU domain" do
      assert Members.valid_tamu_email?("user@TAMUT.EDU")
    end

    test "accepts uppercase email with @ACE.TAMUT.EDU subdomain" do
      assert Members.valid_tamu_email?("USER@ACE.TAMUT.EDU")
    end

    test "accepts mixed-case email" do
      assert Members.valid_tamu_email?("User@Tamu.Edu")
    end

    test "rejects non-tamu emails" do
      refute Members.valid_tamu_email?("user@gmail.com")
    end

    test "rejects emails with similar but incorrect domain" do
      refute Members.valid_tamu_email?("user@notatamu.edu")
    end

    test "rejects nil" do
      refute Members.valid_tamu_email?(nil)
    end

    test "rejects empty string" do
      refute Members.valid_tamu_email?("")
    end
  end
end
