defmodule IeeeTamuPortal.Members do
  @moduledoc """
  The Members context.

  This module provides functions for managing member-related data including
  personal information, resumes, payments, and registrations. It serves as the
  business logic layer for all member operations in the IEEE TAMU Portal.

  ## Member Information

  Member info contains personal details like name, UIN, major, graduation year,
  and other demographic information required for IEEE membership.

  ## Resumes

  Members can upload PDF resumes that are stored in S3 and made available
  for recruitment purposes.

  ## Registrations and Payments

  Each academic year, members must register and pay dues. The system tracks
  registrations per year and associated payments or payment overrides.
  """

  import Ecto.Query, warn: false
  alias IeeeTamuPortal.Repo

  alias IeeeTamuPortal.Members.{Info, Resume, Payment, Registration}

  ## Database getters

  @doc """
  Gets member info by member ID.

  Returns the member info struct if found, nil otherwise.

  ## Parameters

    * `member_id` - The integer ID of the member

  ## Examples

      iex> get_info_by_member_id(123)
      %Info{first_name: "John", last_name: "Doe", ...}

      iex> get_info_by_member_id(456)
      nil

  """
  def get_info_by_member_id(member_id) when is_integer(member_id) do
    Repo.get_by(Info, member_id: member_id)
  end

  @doc """
  Gets member info by UIN (University Identification Number).

  UINs are unique identifiers for Texas A&M students.

  ## Parameters

    * `uin` - The integer UIN of the student

  ## Examples

      iex> get_info_by_uin(123004567)
      %Info{uin: 123004567, first_name: "John", ...}

      iex> get_info_by_uin(999999999)
      nil
  """
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

  @doc """
  Gets a member with flexible preloading options using a single query.

  ## Parameters

    * `member_id` - The ID of the member to fetch
    * `preloads` - List of associations to preload (defaults to [:info, :resume])

  ## Examples

      iex> get_member_with_preloads(123)
      %Member{info: %Info{}, resume: %Resume{}}

      iex> get_member_with_preloads(123, [:info, :registrations])
      %Member{info: %Info{}, registrations: [%Registration{}]}
  """
  def get_member_with_preloads(member_id, preloads \\ [:info, :resume]) do
    from(m in IeeeTamuPortal.Accounts.Member,
      where: m.id == ^member_id,
      preload: ^preloads
    )
    |> Repo.one()
  end

  ## Changesets

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking member info changes.

  This changeset is used for form validation and updating member information
  including personal details, academic information, and contact data.

  ## Parameters

    * `info` - The member info struct (can be new or existing)
    * `attrs` - A map of attributes to validate (optional, defaults to empty map)

  ## Examples

      iex> change_member_info(info)
      %Ecto.Changeset{data: %Info{}}

      iex> change_member_info(info, %{first_name: "John"})
      %Ecto.Changeset{data: %Info{}, changes: %{first_name: "John"}}

  """
  def change_member_info(info, attrs \\ %{}) do
    info = info || %Info{}
    Info.changeset(info, attrs)
  end

  @doc """
  Updates the member info with the given attributes.

  ## Parameters

    * `info` - The member info struct to update
    * `attrs` - A map of attributes to update

  ## Examples

      iex> update_member_info(info, %{first_name: "Jane"})
      {:ok, %Info{first_name: "Jane"}}

      iex> update_member_info(info, %{uin: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_info(info, attrs) do
    info
    |> Info.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates member info for a new member.

  ## Parameters

    * `member` - The member struct to create info for
    * `attrs` - A map of info attributes

  ## Examples

      iex> create_member_info(member, %{first_name: "John", last_name: "Doe"})
      {:ok, %Info{}}

      iex> create_member_info(member, %{})
      {:error, %Ecto.Changeset{}}

  """
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
  Gets a payment by order_id (primary key).

  ## Examples

      iex> get_payment("202507311846543792838986")
      %Payment{}

      iex> get_payment("invalid_order_id")
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
    Ecto.build_assoc(member, :registrations)
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

      case update_registration(registration, %{payment_override: new_override_value}) do
        {:ok, updated_registration} ->
          # Trigger Discord role synchronization when payment status changes
          IeeeTamuPortal.Discord.RoleSyncService.sync_member(member)
          {:ok, updated_registration}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def get_payments_by_api_key(api_key) do
    case api_key.context do
      :admin ->
        {:ok, Repo.all(Payment)}

      :member ->
        if api_key.member_id do
          payments =
            from(p in Payment,
              join: r in Registration,
              on: p.registration_id == r.id,
              where: r.member_id == ^api_key.member_id,
              select: p
            )
            |> Repo.all()

          {:ok, payments}
        else
          {:ok, []}
        end
    end
  end

  def get_payment_by_id_and_api_key(id, api_key) do
    case api_key.context do
      :admin ->
        case Repo.get(Payment, id) do
          nil -> {:error, :not_found}
          payment -> {:ok, payment}
        end

      :member ->
        if api_key.member_id do
          from(p in Payment,
            join: r in Registration,
            on: p.registration_id == r.id,
            where: r.member_id == ^api_key.member_id and p.id == ^id
          )
          |> Repo.one()
          |> case do
            nil -> {:error, :not_found}
            payment -> {:ok, payment}
          end
        else
          {:error, :not_found}
        end
    end
  end

  def associate_payment_with_registration(payment) do
    case payment.confirmation_code do
      nil ->
        {:error, :no_confirmation_code}

      confirmation_code ->
        case Repo.get_by(Registration, confirmation_code: confirmation_code) do
          nil ->
            {:error, :registration_not_found}

          registration ->
            case payment
                 |> Payment.registration_changeset(%{registration_id: registration.id})
                 |> Repo.update() do
              {:ok, updated_payment} ->
                # Get the member for Discord role sync
                member = Repo.get!(IeeeTamuPortal.Accounts.Member, registration.member_id)
                IeeeTamuPortal.Discord.RoleSyncService.sync_member(member)
                {:ok, updated_payment}

              {:error, changeset} ->
                {:error, changeset}
            end
        end
    end
  end

  ## Payment Status Functions

  @doc """
  Gets the payment status for a member in a specific year.

  Returns one of :paid, :override, or :unpaid.

  ## Parameters

    * `member` - The member struct with preloaded registrations
    * `year` - The year to check payment status for (integer)

  ## Examples

      iex> get_payment_status(member, 2024)
      :paid

      iex> get_payment_status(member_with_override, 2024)
      :override

      iex> get_payment_status(member_without_payment, 2024)
      :unpaid
  """
  def get_payment_status(member, year) do
    case member.registrations do
      nil ->
        :pending

      regs ->
        regs
        |> Enum.filter(&(&1.year == year))
        |> case do
          [] -> :pending
          [reg] -> reg.payment_status
        end
    end
  end

  @doc """
  Checks if a member has paid for a specific year.

  ## Parameters

    * `member` - The member struct with preloaded registrations
    * `year` - The year to check payment for (integer)

  ## Examples

      iex> has_paid?(member, 2024)
      true

      iex> has_paid?(unpaid_member, 2024)
      false
  """
  def has_paid?(member, year) do
    get_payment_status(member, year) in [:paid, :override]
  end

  @doc """
  Checks if a member has a payment override for a specific year.

  ## Parameters

    * `member` - The member struct with preloaded registrations
    * `year` - The year to check payment override for (integer)

  ## Examples

      iex> has_payment_override?(member, 2024)
      true

      iex> has_payment_override?(regular_member, 2024)
      false
  """
  def has_payment_override?(member, year) do
    get_payment_status(member, year) == :override
  end
end
