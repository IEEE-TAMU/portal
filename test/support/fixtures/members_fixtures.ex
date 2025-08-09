defmodule IeeeTamuPortal.MembersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `IeeeTamuPortal.Members` context.
  """

  alias IeeeTamuPortal.{Members, AccountsFixtures}

  def registration_fixture(member \\ nil, attrs \\ %{}) do
    member = member || AccountsFixtures.member_fixture()

    {:ok, registration} =
      attrs
      |> then(&Members.create_registration(member, &1))

    registration
  end

  def valid_payment_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      :id => "payment#{System.unique_integer()}",
      :name => "Test Member",
      :amount => 25.00,
      :tshirt_size => "M"
    })
  end

  def payment_fixture(member \\ nil, attrs \\ %{}) do
    member = member || AccountsFixtures.member_fixture()
    registration = registration_fixture(member)

    payment_attrs =
      attrs
      |> valid_payment_attributes()
      |> Map.put(:registration_id, registration.id)
      |> Map.put(:confirmation_code, registration.confirmation_code)

    {:ok, payment} = Members.create_payment(payment_attrs)

    # Associate the payment with registration
    case Members.associate_payment_with_registration(payment) do
      {:ok, updated_payment} -> updated_payment
      {:error, _} -> payment
    end
  end

  def payment_fixture_with_registration(
        member \\ nil,
        registration_attrs \\ %{},
        payment_attrs \\ %{}
      ) do
    member = member || AccountsFixtures.member_fixture()
    registration = registration_fixture(member, registration_attrs)

    payment_attrs =
      payment_attrs
      |> valid_payment_attributes()
      |> Map.put(:registration_id, registration.id)
      |> Map.put(:confirmation_code, registration.confirmation_code)

    {:ok, payment} = Members.create_payment(payment_attrs)

    # Associate the payment with registration
    case Members.associate_payment_with_registration(payment) do
      {:ok, updated_payment} -> updated_payment
      {:error, _} -> payment
    end
  end
end
