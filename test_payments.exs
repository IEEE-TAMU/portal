alias IeeeTamuPortal.{Repo, Accounts.Member, Members.Registration, Members.Payment}

# Test Payment creation
payment_attrs = %{
  amount: Decimal.new("25.00"),
  confirmation_code: "PAY123456",
  tshirt_size: :M,
  contact_email: "john.doe@example.com",
  name: "John Doe"
}

payment_changeset = Payment.changeset(%Payment{}, payment_attrs)
IO.puts("Payment changeset valid? #{payment_changeset.valid?}")

if payment_changeset.valid? do
  payment = Repo.insert!(payment_changeset)
  IO.puts("Created payment with ID: #{payment.id}")

  # Test Registration with Payment
  case Repo.all(Member) |> List.first() do
    nil ->
      IO.puts("No members found to test registration")

    member ->
      registration_attrs = %{
        member_id: member.id,
        payment_id: payment.id
      }

      registration_changeset =
        Registration.create_changeset(%Registration{}, registration_attrs, member)

      if registration_changeset.valid? do
        registration = Repo.insert!(registration_changeset)
        IO.puts("Created registration with confirmation code: #{registration.confirmation_code}")

        # Test associations
        registration_with_associations = Repo.preload(registration, [:member, :payment])
        IO.puts("Registration belongs to member: #{registration_with_associations.member.email}")
        IO.puts("Registration payment amount: #{registration_with_associations.payment.amount}")

        # Test reverse association
        payment_with_registrations = Repo.preload(payment, :registrations)
        IO.puts("Payment has #{length(payment_with_registrations.registrations)} registrations")
      else
        IO.puts("Registration changeset errors: #{inspect(registration_changeset.errors)}")
      end
  end
else
  IO.puts("Payment changeset errors: #{inspect(payment_changeset.errors)}")
end

# Test t-shirt size enum values
IO.puts("\nTesting t-shirt size enum values:")

for size <- [:S, :M, :L, :XL, :XXL] do
  changeset =
    Payment.changeset(%Payment{}, %{
      amount: Decimal.new("20.00"),
      confirmation_code: "TEST_#{size}",
      tshirt_size: size,
      contact_email: "test@example.com",
      name: "Test User"
    })

  IO.puts("T-shirt size #{size}: #{if changeset.valid?, do: "valid", else: "invalid"}")
end
