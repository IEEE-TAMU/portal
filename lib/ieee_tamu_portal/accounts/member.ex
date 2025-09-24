defmodule IeeeTamuPortal.Accounts.Member do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:confirmed_at, :email, :inserted_at, :updated_at, :full_name],
    sortable: [:id, :email, :confirmed_at, :inserted_at, :updated_at],
    join_fields: [
      first_name: [
        binding: :info,
        field: :first_name,
        ecto_type: :string
      ],
      last_name: [
        binding: :info,
        field: :last_name,
        ecto_type: :string
      ],
      preferred_name: [
        binding: :info,
        field: :preferred_name,
        ecto_type: :string
      ]
    ],
    adapter_opts: [
      compound_fields: [full_name: [:preferred_name, :first_name, :last_name]]
    ]
  }
  schema "members" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime

    timestamps(type: :utc_datetime)
    has_many :tokens, IeeeTamuPortal.Accounts.MemberToken
    has_one :info, IeeeTamuPortal.Members.Info
    has_one :resume, IeeeTamuPortal.Members.Resume
    has_many :registrations, IeeeTamuPortal.Members.Registration
    has_many :event_checkins, IeeeTamuPortal.Members.EventCheckin
    has_many :api_keys, IeeeTamuPortal.Api.ApiKey
    has_many :secondary_auth_methods, IeeeTamuPortal.Accounts.AuthMethod
    has_many :rsvps, IeeeTamuPortal.Events.RSVP
  end

  def list_members(params) do
    alias IeeeTamuPortal.Members.Registration
    import Ecto.Query

    query =
      from(m in __MODULE__,
        left_join: info in assoc(m, :info),
        as: :info,
        preload: [info: info]
      )
      |> preload([:resume, registrations: ^Registration.with_payment_status()])

    Flop.validate_and_run!(query, params, for: __MODULE__, replace_invalid_params: true)
  end

  @doc """
  A member changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(member, attrs, opts \\ []) do
    member
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@tamu\.edu$/i, message: "must be a TAMU email")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, IeeeTamuPortal.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A member changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(member, attrs, opts \\ []) do
    member
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A member changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(member, attrs, opts \\ []) do
    member
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(member) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(member, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no member or the member doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%IeeeTamuPortal.Accounts.Member{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def put_resume(%__MODULE__{} = member, %Phoenix.LiveView.UploadEntry{} = entry) do
    put_resume(member, entry, :either)
  end

  def put_resume(%__MODULE__{} = member, %Phoenix.LiveView.UploadEntry{} = entry, looking_for)
      when looking_for in [:full_time, :internship, :either] or is_binary(looking_for) do
    alias IeeeTamuPortal.Members.Resume

    existing_resume = member |> IeeeTamuPortal.Repo.preload(:resume) |> Map.get(:resume)

    resume = existing_resume || Ecto.build_assoc(member, :resume)

    looking_for =
      case looking_for do
        lf when lf in [:full_time, :internship, :either] -> lf
        "Full-Time" -> :full_time
        "Internship" -> :internship
        "Either" -> :either
        "full_time" -> :full_time
        "internship" -> :internship
        "either" -> :either
        _ -> :either
      end

    changeset =
      Resume.changeset(resume, %{
        original_filename: entry.client_name,
        key: Resume.key(member, entry),
        looking_for: looking_for
      })

    case IeeeTamuPortal.Repo.insert_or_update(changeset) do
      {:ok, resume} -> {:ok, %__MODULE__{member | resume: resume}}
      {:error, cs} -> {:error, cs}
    end
  end

  def delete_resume(%__MODULE__{} = member) do
    alias IeeeTamuPortal.Members.Resume

    case member.resume do
      nil ->
        {:ok, member}

      resume ->
        {:ok, _} = Resume.delete(resume)
        {:ok, %__MODULE__{member | resume: nil}}
    end
  end

  def update_resume_looking_for(%__MODULE__{} = member, looking_for) do
    alias IeeeTamuPortal.Members.Resume

    case member.resume do
      nil ->
        {:ok, member}

      %Resume{} = resume ->
        looking_for =
          case looking_for do
            lf when lf in [:full_time, :internship, :either] -> lf
            "Full-Time" -> :full_time
            "Internship" -> :internship
            "Either" -> :either
            "full_time" -> :full_time
            "internship" -> :internship
            "either" -> :either
            _ -> :either
          end

        changeset = Resume.changeset(resume, %{looking_for: looking_for})

        case IeeeTamuPortal.Repo.update(changeset) do
          {:ok, updated} -> {:ok, %__MODULE__{member | resume: updated}}
          {:error, cs} -> {:error, cs}
        end
    end
  end

  @doc """
  Returns true if the member has an EventCheckin for the current event and registration year.

  Accepts a Member struct or a member id.
  If the current event is the default "NONE", this always returns false.
  """
  def member_is_checked_in?(%__MODULE__{id: id}), do: member_is_checked_in?(id)

  def member_is_checked_in?(member_id) when is_integer(member_id) or is_binary(member_id) do
    import Ecto.Query
    alias IeeeTamuPortal.Members.EventCheckin

    event_name = IeeeTamuPortal.Settings.get_current_event!()

    if event_name == IeeeTamuPortal.Settings.default_current_event() do
      false
    else
      event_year = IeeeTamuPortal.Settings.get_registration_year!()

      member_id =
        case member_id do
          id when is_integer(id) ->
            id

          bin when is_binary(bin) ->
            case Integer.parse(bin) do
              {int, _} -> int
              :error -> -1
            end
        end

      query =
        from ec in EventCheckin,
          where:
            ec.member_id == ^member_id and ec.event_name == ^event_name and
              ec.event_year == ^event_year,
          select: 1,
          limit: 1

      IeeeTamuPortal.Repo.exists?(query)
    end
  end
end
