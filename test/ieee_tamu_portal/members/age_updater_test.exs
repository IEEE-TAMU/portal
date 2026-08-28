defmodule IeeeTamuPortal.Members.AgeUpdaterTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import IeeeTamuPortal.AccountsFixtures

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Members.AgeUpdater
  alias IeeeTamuPortal.Members.Info
  alias IeeeTamuPortal.Repo

  # AgeUpdater is started by the application; give it access to this test's
  # sandboxed connection so it can see (and update) the fixtures.
  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: true)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, owner, GenServer.whereis(AgeUpdater))

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    :ok
  end

  defp member_with_age(age) do
    member = member_fixture()

    {:ok, info} =
      Members.create_member_info(member, %{
        first_name: "Test",
        last_name: "User",
        uin: 123_004_567,
        tshirt_size: :M,
        major: :CSCE,
        graduation_year: 2026,
        gender: :Male,
        international_student: false,
        age: age
      })

    {member, info}
  end

  defp backdate(info, days) do
    old = DateTime.add(DateTime.utc_now(), -days, :day)

    from(i in Info, where: i.id == ^info.id)
    |> Repo.update_all(set: [updated_at: old])
  end

  test "force_update/0 increments the age of infos not updated in over a year" do
    {_member, info} = member_with_age(20)
    backdate(info, 400)

    assert {:ok, 1} = AgeUpdater.force_update()
    assert Repo.get!(Info, info.id).age == 21
  end

  test "force_update/0 skips infos updated recently" do
    {_member, info} = member_with_age(30)
    backdate(info, 0)

    assert {:ok, 0} = AgeUpdater.force_update()
    assert Repo.get!(Info, info.id).age == 30
  end

  test "force_update/0 skips infos without an age" do
    member = member_fixture()

    {:ok, info} =
      Members.create_member_info(member, %{
        first_name: "Test",
        last_name: "User",
        uin: 123_004_568,
        tshirt_size: :M,
        major: :CSCE,
        graduation_year: 2026,
        gender: :Male,
        international_student: false
      })

    backdate(info, 400)

    assert {:ok, 0} = AgeUpdater.force_update()
    assert Repo.get!(Info, info.id).age == nil
  end

  test "the daily run updates stale ages" do
    {_member, info} = member_with_age(20)
    backdate(info, 400)

    send(AgeUpdater, :update_ages)

    wait_until(fn -> Repo.get!(Info, info.id).age == 21 end)
  end

  defp wait_until(fun, attempts \\ 100)

  defp wait_until(_fun, 0), do: flunk("condition was never met")

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      wait_until(fun, attempts - 1)
    end
  end
end
