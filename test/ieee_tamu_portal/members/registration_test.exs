defmodule IeeeTamuPortal.Members.RegistrationTest do
  use IeeeTamuPortal.DataCase, async: true

  import Ecto.Query
  alias IeeeTamuPortal.Members.Registration
  alias IeeeTamuPortal.Settings
  import IeeeTamuPortal.{AccountsFixtures, MembersFixtures, SettingsFixtures}

  describe "payment_override preserves historical data" do
    test "old override persists when registration year changes" do
      old_year_setting = registration_year_setting_fixture("2024")

      member = member_fixture()
      old_reg = registration_fixture(member, %{year: 2024, payment_override: true})
      assert old_reg.payment_override == true

      assert {:ok, _} = Settings.update_setting(old_year_setting, %{value: "2025"})

      old_reg_reloaded = IeeeTamuPortal.Repo.reload(old_reg)
      assert old_reg_reloaded.payment_override == true
    end
  end

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
