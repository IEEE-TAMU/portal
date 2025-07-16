defmodule IeeeTamuPortal.Members.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "registrations" do
    field :year, :integer,
      autogenerate: {IeeeTamuPortal.Settings, :get_setting, ["registeration_year"]}

    field(:confirmation_code, :string)
    field :payment_override, :boolean, default: false

    belongs_to :member, IeeeTamuPortal.Accounts.Member
    has_one :payment, IeeeTamuPortal.Members.Payment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:confirmation_code, :payment_override, :member_id])
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
    |> cast(attrs_with_code, [:confirmation_code, :payment_override, :member_id])
    |> validate_required([:confirmation_code, :member_id])
    |> unique_constraint(:confirmation_code)
    |> foreign_key_constraint(:member_id)
  end
end
