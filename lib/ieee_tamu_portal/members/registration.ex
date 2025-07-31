defmodule IeeeTamuPortal.Members.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "registrations" do
    field :year, :integer, autogenerate: {IeeeTamuPortal.Settings, :get_registration_year!, []}

    field :confirmation_code, :string
    field :payment_override, :boolean, default: false

    belongs_to :member, IeeeTamuPortal.Accounts.Member
    has_one :payment, IeeeTamuPortal.Members.Payment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:year, :confirmation_code, :payment_override, :member_id])
    |> validate_required([:confirmation_code, :member_id])
    |> unique_constraint(:confirmation_code)
    |> foreign_key_constraint(:member_id)
  end

  @doc """
  Generates a confirmation code based on the member's email.
  Uses the part before the @ sign plus a timestamp-based suffix.
  """
  def generate_confirmation_code(member_email) do
    email_prefix =
      member_email
      |> String.split("@")
      |> List.first()
      |> String.replace(~r/[^a-zA-Z0-9]/, "")
      |> String.upcase()

    # Add timestamp suffix to ensure uniqueness
    timestamp_suffix =
      DateTime.utc_now()
      |> DateTime.to_unix()
      |> Integer.to_string()
      |> String.slice(-6..-1)

    "#{email_prefix}#{timestamp_suffix}"
  end

  @doc """
  Creates a changeset for a new registration with auto-generated confirmation code.
  """
  def create_changeset(registration, attrs, member) do
    confirmation_code = generate_confirmation_code(member.email)

    attrs_with_code = Map.put(attrs, :confirmation_code, confirmation_code)

    registration
    |> cast(attrs_with_code, [:year, :confirmation_code, :payment_override, :member_id])
    |> validate_required([:confirmation_code, :member_id])
    |> unique_constraint(:confirmation_code)
    |> foreign_key_constraint(:member_id)
  end

  @doc """
  Checks if the registration payment is complete.
  Returns true if payment_override is true OR there's an associated payment.
  """
  def payment_complete?(registration) do
    registration.payment_override || registration.payment != nil
  end

  @doc """
  Counts the number of paid members for a specific year.
  A member is considered paid if they have payment_override = true OR an associated payment.
  """
  def paid_members_count_for_year(year) do
    alias IeeeTamuPortal.{Repo, Members.Payment}
    import Ecto.Query

    from(r in __MODULE__,
      left_join: p in Payment,
      on: r.id == p.registration_id,
      where: r.year == ^year and (r.payment_override == true or not is_nil(p.id))
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Checks if a member has paid for a specific year.
  Returns true if the member has a registration with payment_override = true OR an associated payment.
  """
  def member_paid_for_year?(member_id, year) do
    alias IeeeTamuPortal.{Repo, Members.Payment}
    import Ecto.Query

    query =
      from(r in __MODULE__,
        left_join: p in Payment,
        on: r.id == p.registration_id,
        where:
          r.member_id == ^member_id and r.year == ^year and
            (r.payment_override == true or not is_nil(p.id))
      )

    Repo.exists?(query)
  end

  @doc """
  Gets existing registration for a member and year, or creates a new one if none exists.
  """
  def get_or_create_registration_for_member(member, year) do
    alias IeeeTamuPortal.Repo
    import Ecto.Query

    # First try to find existing registration
    case from(r in __MODULE__,
           where: r.member_id == ^member.id and r.year == ^year,
           limit: 1
         )
         |> Repo.one() do
      nil ->
        # No registration exists, create one
        %__MODULE__{}
        |> create_changeset(%{member_id: member.id, year: year}, member)
        |> Repo.insert()

      registration ->
        # Registration exists
        {:ok, registration}
    end
  end

  @doc """
  Checks if a member has payment override enabled for a specific year.
  """
  def member_has_payment_override?(member_id, year) do
    alias IeeeTamuPortal.Repo
    import Ecto.Query

    from(r in __MODULE__,
      where: r.member_id == ^member_id and r.year == ^year and r.payment_override == true
    )
    |> Repo.exists?()
  end
end
