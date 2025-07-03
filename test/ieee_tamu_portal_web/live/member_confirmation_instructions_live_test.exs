defmodule IeeeTamuPortalWeb.MemberConfirmationInstructionsLiveTest do
  use IeeeTamuPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Repo

  setup do
    %{member: member_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/members/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, member: member} do
      {:ok, lv, _html} = live(conn, ~p"/members/confirm")

      assert lv
             |> form("#resend_confirmation_form", member: %{email: member.email})
             |> render_submit() =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.MemberToken, member_id: member.id).context == "confirm"
    end

    test "does not send confirmation token if member is confirmed", %{conn: conn, member: member} do
      Repo.update!(Accounts.Member.confirm_changeset(member))

      {:ok, lv, _html} = live(conn, ~p"/members/confirm")

      assert lv
             |> form("#resend_confirmation_form", member: %{email: member.email})
             |> render_submit() =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.MemberToken, member_id: member.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/members/confirm")

      assert lv
             |> form("#resend_confirmation_form", member: %{email: "unknown@example.com"})
             |> render_submit() =~
               "If your email is in our system"

      assert Repo.all(Accounts.MemberToken) == []
    end
  end
end
