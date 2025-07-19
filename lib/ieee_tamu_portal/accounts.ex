defmodule IeeeTamuPortal.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Accounts.{Member, MemberToken, MemberNotifier, ApiKey}

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

  ## API Keys

  @doc """
  Lists all API keys.

  ## Examples

      iex> list_api_keys()
      [%ApiKey{}, ...]

  """
  def list_api_keys do
    Repo.all(from k in ApiKey, order_by: [desc: k.inserted_at])
  end

  @doc """
  Gets a single API key.

  Raises `Ecto.NoResultsError` if the API key does not exist.

  ## Examples

      iex> get_api_key!(123)
      %ApiKey{}

      iex> get_api_key!(456)
      ** (Ecto.NoResultsError)

  """
  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Creates an API key.

  ## Examples

      iex> create_api_key(%{name: "My API Key"})
      {:ok, {plain_token, %ApiKey{}}}

      iex> create_api_key(%{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_key(attrs \\ %{}) do
    {plain_token, changeset} = ApiKey.build_api_key(attrs)

    case Repo.insert(changeset) do
      {:ok, api_key} -> {:ok, {plain_token, api_key}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an API key.

  ## Examples

      iex> update_api_key(api_key, %{name: "Updated Name"})
      {:ok, %ApiKey{}}

      iex> update_api_key(api_key, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an API key.

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %ApiKey{}}

      iex> delete_api_key(api_key)
      {:error, %Ecto.Changeset{}}

  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking API key changes.

  ## Examples

      iex> change_api_key(api_key)
      %Ecto.Changeset{data: %ApiKey{}}

  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Verifies an API token and returns the API key if valid.

  ## Examples

      iex> verify_api_token("portal_api_abc123")
      {:ok, %ApiKey{}}

      iex> verify_api_token("invalid_token")
      {:error, :invalid_token}

  """
  def verify_api_token(token) when is_binary(token) do
    case Repo.one(ApiKey.verify_token(token)) do
      %ApiKey{} = api_key ->
        # Update last_used_at timestamp
        api_key
        |> ApiKey.touch_last_used()
        |> Repo.update()

        {:ok, api_key}

      nil ->
        {:error, :invalid_token}
    end
  end
end
