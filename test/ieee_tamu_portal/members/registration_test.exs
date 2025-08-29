defmodule IeeeTamuPortal.Members.RegistrationTest do
  use IeeeTamuPortal.DataCase, async: true

  import Ecto.Query
  alias IeeeTamuPortal.Members.{Registration}
  import IeeeTamuPortal.{AccountsFixtures, MembersFixtures}

  describe "with_payment_status/1" do
    test "marks pending when no payment and no override" do
      member = member_fixture()
      _registration = registration_fixture(member)

      regs =
        Registration
        |> where([r], r.member_id == ^member.id)
        |> Registration.with_payment_status()
        |> IeeeTamuPortal.Repo.all()

      assert Enum.all?(regs, &(&1.payment_status == :pending))
    end

    test "marks paid when payment exists" do
      member = member_fixture()
      _payment = payment_fixture(member)

      [reg] =
        Registration
        |> where([r], r.member_id == ^member.id)
        |> Registration.with_payment_status()
        |> IeeeTamuPortal.Repo.all()

      assert reg.payment_status == :paid
    end

    test "marks override when payment_override is true" do
      member = member_fixture()

      {:ok, reg} =
        IeeeTamuPortal.Members.create_registration(member, %{payment_override: true})

      [loaded] =
        Registration
        |> where([r], r.id == ^reg.id)
        |> Registration.with_payment_status()
        |> IeeeTamuPortal.Repo.all()

      assert loaded.payment_status == :override
    end
  end

  describe "put_payment_status/1" do
    test "handles a loaded struct with payment preloaded" do
      member = member_fixture()
      _payment = payment_fixture(member)

      reg =
        Registration
        |> where([r], r.member_id == ^member.id)
        |> IeeeTamuPortal.Repo.one()
        |> IeeeTamuPortal.Repo.preload(:payment)

      reg = Registration.put_payment_status(reg)
      assert reg.payment_status == :paid
    end

    test "handles not-loaded payment association as pending" do
      member = member_fixture()
      reg = registration_fixture(member)

      reg = Registration.put_payment_status(reg)
      assert reg.payment_status == :pending
    end
  end
end
