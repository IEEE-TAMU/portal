alias IeeeTamuPortal.{Repo, Accounts.Member, Members.Registration}

# Test the confirmation code generation
test_email = "john.doe@example.com"
confirmation_code = Registration.generate_confirmation_code(test_email)
IO.puts("Generated confirmation code for #{test_email}: #{confirmation_code}")

# Test with different email patterns
test_emails = [
  "jane.smith@tamu.edu",
  "bob-wilson@gmail.com",
  "alice_johnson@ieee.org",
  "test.user+tag@domain.com"
]

Enum.each(test_emails, fn email ->
  code = Registration.generate_confirmation_code(email)
  IO.puts("#{email} -> #{code}")
end)

# Test getting a member and creating a registration
case Repo.all(Member) |> List.first() do
  nil ->
    IO.puts("\nNo members found in database to test registration creation")

  member ->
    IO.puts("\nTesting registration creation for member: #{member.email}")

    changeset = Registration.create_changeset(%Registration{}, %{member_id: member.id}, member)

    if changeset.valid? do
      IO.puts("Registration changeset is valid!")
      IO.puts("Confirmation code: #{changeset.changes.confirmation_code}")
    else
      IO.puts("Registration changeset errors: #{inspect(changeset.errors)}")
    end
end
