defmodule IeeeTamuPortal.Accounts do
  @moduledoc """
  The Accounts context.

  This module provides functions for managing member accounts in the IEEE TAMU Portal.
  It handles member registration, authentication, email updates, password changes,
  and member data retrieval. The context includes functionality for:

  - Member registration and profile management
  - Authentication and password verification
  - Email verification and updates
  - Member data queries and aggregations
  - Resume management integration

  ## Member Authentication

  The module provides secure authentication through email/password combinations
  and includes password hashing, session token management, and email confirmation.

  ## Data Access Patterns

  Functions follow consistent naming patterns:
  - `get_*` functions retrieve single records and may raise if not found
  - `list_*` functions return collections of records
  - `create_*`, `update_*`, `delete_*` functions perform write operations
  - `change_*` functions return changesets for form handling

  ## Examples

      # Register a new member
      {:ok, member} = Accounts.register_member(%{
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        password: "secure_password"
      })

      # Authenticate existing member
      {:ok, member} = Accounts.get_member_by_email_and_password(
        "john@example.com",
        "secure_password"
      )

      # Get member count
      total_members = Accounts.count_members()
  """

  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Accounts.{
    Member,
    MemberToken,
    MemberNotifier,
    AuthMethod
  }

  ## Database getters

  @doc """
  Gets the total count of members.

  ## Examples

      iex> count_members()
      42

  """
  def count_members do
    Repo.aggregate(Member, :count, :id)
  end

  @doc """
  Gets all members.

  ## Examples

      iex> list_members()
      [%Member{}, ...]

  """
  def list_members do
    Repo.all(Member)
    |> Repo.preload(:resume)
  end

  @doc """
  Gets all members with their registrations for a specific year.
  This is optimized to avoid N+1 queries when checking payment status.

  ## Examples

      iex> list_members_with_registrations(2024)
      [%Member{registrations: [%Registration{}, ...]}, ...]

  """
  def list_members_with_registrations(year) do
    alias IeeeTamuPortal.Members.{Registration, Payment}
    import Ecto.Query

    from(m in Member,
      left_join: r in Registration,
      on: m.id == r.member_id and r.year == ^year,
      left_join: p in Payment,
      on: r.id == p.registration_id,
      preload: [
        :resume,
        registrations: {r, payment: p}
      ]
    )
    |> Repo.all()
  end

  @doc """
  Gets a member by email.

  ## Examples

      iex> get_member_by_email("foo@example.com")
      %Member{}

      iex> get_member_by_email("unknown@example.com")
      nil

  """
  def get_member_by_email(email) when is_binary(email) do
    Repo.get_by(Member, email: email)
  end

  @doc """
  Gets a member by email and password.

  ## Examples

      iex> get_member_by_email_and_password("foo@example.com", "correct_password")
      %Member{}

      iex> get_member_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_member_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    member = Repo.get_by(Member, email: email)
    if Member.valid_password?(member, password), do: member
  end

  @doc """
  Gets a single member.

  Raises `Ecto.NoResultsError` if the Member does not exist.

  ## Examples

      iex> get_member!(123)
      %Member{}

      iex> get_member!(456)
      ** (Ecto.NoResultsError)

  """
  def get_member!(id), do: Repo.get!(Member, id)

  ## Member registration

  @doc """
  Registers a member.

  ## Examples

      iex> register_member(%{field: value})
      {:ok, %Member{}}

      iex> register_member(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_member(attrs) do
    %Member{}
    |> Member.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking member changes.

  ## Examples

      iex> change_member_registration(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_registration(%Member{} = member, attrs \\ %{}) do
    Member.registration_changeset(member, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member email.

  ## Examples

      iex> change_member_email(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_email(member, attrs \\ %{}) do
    Member.email_changeset(member, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_member_email(member, "valid password", %{email: ...})
      {:ok, %Member{}}

      iex> apply_member_email(member, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_member_email(member, password, attrs) do
    member
    |> Member.email_changeset(attrs)
    |> Member.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the member email using the given token.

  If the token matches, the member email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_member_email(member, token) do
    context = "change:#{member.email}"

    with {:ok, query} <- MemberToken.verify_change_email_token_query(token, context),
         %MemberToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(member_email_multi(member, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp member_email_multi(member, email, context) do
    changeset =
      member
      |> Member.email_changeset(%{email: email})
      |> Member.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, changeset)
    |> Ecto.Multi.delete_all(:tokens, MemberToken.by_member_and_contexts_query(member, [context]))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member password.

  ## Examples

      iex> change_member_password(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_password(member, attrs \\ %{}) do
    Member.password_changeset(member, attrs, hash_password: false)
  end

  @doc """
  Updates the member password.

  ## Examples

      iex> update_member_password(member, "valid password", %{password: ...})
      {:ok, %Member{}}

      iex> update_member_password(member, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_password(member, password, attrs) do
    changeset =
      member
      |> Member.password_changeset(attrs)
      |> Member.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, changeset)
    |> Ecto.Multi.delete_all(:tokens, MemberToken.by_member_and_contexts_query(member, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member}} -> {:ok, member}
      {:error, :member, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_member_session_token(member) do
    {token, member_token} = MemberToken.build_session_token(member)
    Repo.insert!(member_token)
    token
  end

  @doc """
  Gets the member with the given signed token.
  """
  def get_member_by_session_token(token) do
    {:ok, query} = MemberToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_member_session_token(token) do
    Repo.delete_all(MemberToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given member.

  ## Examples

      iex> deliver_member_confirmation_instructions(member, &url(~p"/members/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_member_confirmation_instructions(confirmed_member, &url(~p"/members/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_member_confirmation_instructions(%Member{} = member, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if member.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)

      MemberNotifier.deliver_confirmation_instructions(
        member,
        confirmation_url_fun.(encoded_token)
      )
    end
  end

  @doc """
  Confirms a member by the given token.

  If the token matches, the member account is marked as confirmed
  and the token is deleted.
  """
  def confirm_member(token) do
    with {:ok, query} <- MemberToken.verify_email_token_query(token, "confirm"),
         %Member{} = member <- Repo.one(query),
         {:ok, %{member: member}} <- Repo.transaction(confirm_member_multi(member)) do
      {:ok, member}
    else
      _ -> :error
    end
  end

  defp confirm_member_multi(member) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, Member.confirm_changeset(member))
    |> Ecto.Multi.delete_all(
      :tokens,
      MemberToken.by_member_and_contexts_query(member, ["confirm"])
    )
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given member.

  ## Examples

      iex> deliver_member_reset_password_instructions(member, &url(~p"/members/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_member_reset_password_instructions(%Member{} = member, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
    Repo.insert!(member_token)

    MemberNotifier.deliver_reset_password_instructions(
      member,
      reset_password_url_fun.(encoded_token)
    )
  end

  @doc """
  Gets the member by reset password token.

  ## Examples

      iex> get_member_by_reset_password_token("validtoken")
      %Member{}

      iex> get_member_by_reset_password_token("invalidtoken")
      nil

  """
  def get_member_by_reset_password_token(token) do
    with {:ok, query} <- MemberToken.verify_email_token_query(token, "reset_password"),
         %Member{} = member <- Repo.one(query) do
      member
    else
      _ -> nil
    end
  end

  @doc """
  Resets the member password.

  ## Examples

      iex> reset_member_password(member, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Member{}}

      iex> reset_member_password(member, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_member_password(member, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, Member.password_changeset(member, attrs))
    |> Ecto.Multi.delete_all(:tokens, MemberToken.by_member_and_contexts_query(member, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member}} -> {:ok, member}
      {:error, :member, changeset, _} -> {:error, changeset}
    end
  end

  def preload_member_info(member) do
    member
    |> Repo.preload(:info)
  end

  def preload_member_resume(member) do
    member
    |> Repo.preload(:resume)
  end

  ## Auth Methods

  @doc """
  Links an authentication method to a member.

  ## Examples

      iex> link_auth_method(member, %{provider: :discord, sub: "123456"})
      {:ok, %AuthMethod{}}

      iex> link_auth_method(member, %{provider: :discord})
      {:error, %Ecto.Changeset{}}

  """
  def link_auth_method(%Member{} = member, attrs) do
    Ecto.build_assoc(member, :secondary_auth_methods)
    |> AuthMethod.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an authentication method by member and provider.

  ## Examples

      iex> get_auth_method(member, :discord)
      %AuthMethod{}

      iex> get_auth_method(member, :discord)
      nil

  """
  def get_auth_method(%Member{} = member, provider) do
    Repo.get_by(AuthMethod, member_id: member.id, provider: provider)
  end

  # @doc """
  # Lists all authentication methods for a member.

  # ## Examples

  #     iex> list_auth_methods(member)
  #     [%AuthMethod{}, ...]

  # """
  def list_auth_methods(%Member{} = member) do
    import Ecto.Query

    from(am in AuthMethod,
      where: am.member_id == ^member.id,
      order_by: am.provider
    )
    |> Repo.all()
  end

  @doc """
  Removes an authentication method from a member.

  ## Examples

      iex> unlink_auth_method(member, :discord)
      {:ok, %AuthMethod{}}

      iex> unlink_auth_method(member, :nonexistent)
      {:error, :not_found}

  """
  def unlink_auth_method(%Member{} = member, provider) do
    case get_auth_method(member, provider) do
      nil ->
        {:error, :not_found}

      auth_method ->
        Repo.delete(auth_method)
    end
  end

  @doc """
  Gets a member by Discord sub (user ID).

  Returns the member if found, nil otherwise.

  ## Examples

      iex> get_member_by_discord_sub("123456789")
      %Member{}

      iex> get_member_by_discord_sub("nonexistent")
      nil
  """
  def get_member_by_discord_sub(discord_sub) do
    import Ecto.Query

    from(m in Member,
      join: auth in AuthMethod,
      on: auth.member_id == m.id,
      where: auth.provider == :discord and auth.sub == ^discord_sub
    )
    |> Repo.one()
  end

  @doc """
  Preloads authentication methods for a member.

  ## Examples

      iex> preload_member_auth_methods(member)
      %Member{secondary_auth_methods: [%AuthMethod{}, ...]}

  """
  def preload_member_auth_methods(member) do
    member
    |> Repo.preload(:secondary_auth_methods)
  end
end
