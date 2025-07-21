defmodule IeeeTamuPortal.Members do
  @moduledoc """
  The Members context.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Members.{Info, Resume, Payment, Registration}

  ## Database getters

  @doc """
  Gets a member info by member id.

  ## Examples

      iex> get_info_by_member_id(123)
      %Info{}

      iex> get_info_by_member_id(456)
      nil

  """
  def get_info_by_member_id(member_id) when is_integer(member_id) do
    Repo.get_by(Info, member_id: member_id)
  end

  def get_info_by_uin(uin) when is_integer(uin) do
    Repo.get_by(Info, uin: uin)
  end

  @doc """
  Gets a member resume by member ID.

  Returns the resume struct if the member has uploaded one, nil otherwise.

  ## Parameters

    * `member_id` - The integer ID of the member

  ## Examples

      iex> get_resume_by_member_id(123)
      %Resume{original_filename: "john_doe_resume.pdf", ...}

      iex> get_resume_by_member_id(456)
      nil

  """
  def get_resume_by_member_id(member_id) when is_integer(member_id) do
    Repo.get_by(Resume, member_id: member_id)
  end

  ## Changesets

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member info.

  ## Examples

      iex> change_member_info(info)
      %Ecto.Changeset{data: %Info{}}

  """
  def change_member_info(info, attrs \\ %{}) do
    info = info || %Info{}
    Info.changeset(info, attrs)
  end

  @doc """
  Updates the member info.

  ## Examples

      iex> update_member_info(info, attrs)
      {:ok, %Info{}}

      iex> update_member_info(info, %{})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_info(info, attrs) do
    info
    |> Info.changeset(attrs)
    |> Repo.update()
  end

  def create_member_info(member, attrs) do
    %Info{member_id: member.id}
    |> Info.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member resume.

  ## Examples

      iex> change_member_resume(resume)
      %Ecto.Changeset{data: %Resume{}}

  """
  def change_member_resume(resume, attrs \\ %{}) do
    resume = resume || %Resume{}
    Resume.changeset(resume, attrs)
  end

  @doc """
  Updates the member resume.

  ## Examples

      iex> update_member_resume(resume, attrs)
      {:ok, %Resume{}}

      iex> update_member_resume(resume, %{})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_resume(resume, attrs) do
    resume
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  def create_member_resume(member, attrs) do
    %Resume{member_id: member.id}
    |> Resume.changeset(attrs)
    |> Repo.insert()
  end

  ## Payment functions

  @doc """
  Creates a payment.

  ## Examples

      iex> create_payment(%{amount: 25.00, confirmation_code: "ABC123"})
      {:ok, %Payment{}}

      iex> create_payment(%{amount: -10})
      {:error, %Ecto.Changeset{}}

  """
  def create_payment(attrs \\ %{}) do
    %Payment{}
    |> Payment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a payment by id.

  ## Examples

      iex> get_payment(123)
      %Payment{}

      iex> get_payment(456)
      nil

  """
  def get_payment(id), do: Repo.get(Payment, id)

  @doc """
  Gets a payment by confirmation code.

  ## Examples

      iex> get_payment_by_confirmation_code("ABC123")
      %Payment{}

      iex> get_payment_by_confirmation_code("INVALID")
      nil

  """
  def get_payment_by_confirmation_code(confirmation_code) do
    Repo.get_by(Payment, confirmation_code: confirmation_code)
  end

  @doc """
  Lists all payments.

  ## Examples

      iex> list_payments()
      [%Payment{}, ...]

  """
  def list_payments do
    Repo.all(Payment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking payment changes.

  ## Examples

      iex> change_payment(payment)
      %Ecto.Changeset{data: %Payment{}}

  """
  def change_payment(%Payment{} = payment, attrs \\ %{}) do
    Payment.changeset(payment, attrs)
  end

  ## Registration Functions

  @doc """
  Gets a registration for a member in a specific year.

  Returns the most recent registration for the given member and year,
  or nil if no registration exists.

  ## Parameters

    * `member_id` - The integer ID of the member
    * `year` - The registration year as integer or string

  ## Examples

      iex> get_registration(123, 2024)
      %Registration{member_id: 123, year: 2024, ...}

      iex> get_registration(123, "2024")
      %Registration{member_id: 123, year: 2024, ...}

      iex> get_registration(999, 2024)
      nil
  """
  def get_registration(member_id, year) when is_integer(member_id) and is_integer(year) do
    from(r in Registration,
      where: r.member_id == ^member_id and r.year == ^year,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_registration(member_id, year) when is_integer(member_id) and is_binary(year) do
    year_int = String.to_integer(year)
    get_registration(member_id, year_int)
  end

  @doc """
  Creates a registration for a member.

  Automatically generates a confirmation code based on the member's email.

  ## Parameters

    * `member` - The member struct to create a registration for
    * `attrs` - Optional attributes map (e.g., custom year)

  ## Examples

      iex> create_registration(member, %{year: 2024})
      {:ok, %Registration{}}

      iex> create_registration(member, %{})
      {:ok, %Registration{}}
  """
  def create_registration(member, attrs \\ %{}) do
    %Registration{}
    |> Registration.create_changeset(attrs, member)
    |> Repo.insert()
  end

  @doc """
  Updates a registration with the given attributes.

  ## Parameters

    * `registration` - The registration struct to update
    * `attrs` - A map of attributes to update

  ## Examples

      iex> update_registration(registration, %{payment_override: true})
      {:ok, %Registration{payment_override: true}}

  Updates a registration with the given attributes.
  """
  def update_registration(registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets or creates a registration for a member and year.
  """
  def get_or_create_registration(member, year) do
    case get_registration(member.id, year) do
      nil ->
        create_registration(member, %{year: year})

      registration ->
        {:ok, registration}
    end
  end

  @doc """
  Gets a registration with preloaded payment.
  """
  def get_registration_with_payment(registration) do
    Repo.preload(registration, :payment)
  end

  # Deletes a member resume.
  def delete_member_resume(member) do
    case member.resume do
      nil ->
        {:ok, member}

      resume ->
        with {:ok, _} <- Resume.delete(resume) do
          {:ok, %{member | resume: nil}}
        end
    end
  end

  # Toggles the payment override for a member registration in a specific year.
  def toggle_payment_override(member, year) do
    with {:ok, registration} <- get_or_create_registration(member, year) do
      new_override_value = !registration.payment_override
      update_registration(registration, %{payment_override: new_override_value})
    end
  end
end
