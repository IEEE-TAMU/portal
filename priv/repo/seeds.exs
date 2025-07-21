# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     IeeeTamuPortal.Repo.insert!(%IeeeTamuPortal.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias IeeeTamuPortal.Accounts
alias IeeeTamuPortal.Members

# Create a test user
case Accounts.register_member(%{
       email: "test@tamu.edu",
       password: "password"
     }) do
  {:ok, member} ->
    # Confirm the member account
    confirmed_member =
      IeeeTamuPortal.Repo.update!(IeeeTamuPortal.Accounts.Member.confirm_changeset(member))

    IO.puts("✓ Created test user: test@tamu.edu with password 'password'")
    IO.puts("  Member ID: #{confirmed_member.id}")

    # Create member info
    case Members.create_member_info(confirmed_member, %{
           first_name: "Caleb",
           last_name: "Norton",
           tshirt_size: :M,
           gender: :Male,
           uin: 574_003_467,
           major: :CPEN,
           graduation_year: 2027,
           international_student: false
         }) do
      {:ok, info} ->
        IO.puts("✓ Created member info for Caleb Norton")
        IO.puts("  UIN: #{info.uin}")
        IO.puts("  Major: #{info.major}")
        IO.puts("  Graduation Year: #{info.graduation_year}")

      {:error, changeset} ->
        IO.puts("✗ Failed to create member info")
        IO.inspect(changeset.errors)
    end

  {:error, changeset} ->
    IO.puts("✗ Failed to create test user")
    IO.inspect(changeset.errors)
end
