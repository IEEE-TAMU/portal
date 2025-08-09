defmodule IeeeTamuPortal.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `IeeeTamuPortal.Accounts` context.
  """

  def unique_member_email, do: "member#{System.unique_integer()}@tamu.edu"
  def invalid_member_email, do: "member#{System.unique_integer()}@example.com"
  def valid_member_password, do: "hello world!"

  def valid_member_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_member_email(),
      password: valid_member_password()
    })
  end

  def member_fixture(attrs \\ %{}) do
    {:ok, member} =
      attrs
      |> valid_member_attributes()
      |> IeeeTamuPortal.Accounts.register_member()

    member
  end

  def confirmed_member_fixture(attrs \\ %{}) do
    member = member_fixture(attrs)
    IeeeTamuPortal.Repo.update!(IeeeTamuPortal.Accounts.Member.confirm_changeset(member))
    member
  end

  def extract_member_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
