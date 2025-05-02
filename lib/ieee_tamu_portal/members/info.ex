defmodule IeeeTamuPortal.Members.Info do
  use Ecto.Schema
  import Ecto.Changeset

  schema "member_infos" do
    field :age, :integer
    field :first_name, :string
    field :graduation_year, :integer
    field :international_country, :string
    field :international_student, :boolean, default: false
    field :last_name, :string
    field :major, Ecto.Enum, values: ~w(ELEN CPEN CSCE ESET MXET ENGR Other)a
    field :major_other, :string
    field :phone_number, :string
    field :preferred_name, :string
    field :gender, Ecto.Enum, values: ~w(Male Female Other)a
    field :gender_other, :string
    field :tshirt_size, Ecto.Enum, values: ~w(S M L XL XXL)a
    field :uin, :integer
    field :ieee_membership_number, :integer

    timestamps(type: :utc_datetime)
    belongs_to :member, IeeeTamuPortal.Accounts.Member
  end

  def personal_info_changeset(info, attrs, opts \\ []) do
    info
    |> cast(attrs, [
      :uin,
      :ieee_membership_number,
      :first_name,
      :last_name,
      :preferred_name,
      :tshirt_size,
      :phone_number,
      :gender,
      :age
    ])
    |> validate_required([
      :first_name,
      :last_name,
      :tshirt_size
    ])
    |> validate_uin(opts)
    |> validate_phone_number()
    |> maybe_change_gender_other(attrs)
  end

  def academic_info_changeset(info, attrs, _opts \\ []) do
    info
    |> cast(attrs, [
      :graduation_year,
      :major,
      :international_student,
      :international_country,
      :ieee_membership_number
    ])
    |> validate_required([
      :graduation_year,
      :major,
      :international_student
    ])
    |> validate_member_number()
    |> maybe_change_major_other(attrs)
    |> maybe_change_international_country(attrs)
  end

  @doc false
  def changeset(info, attrs, opts \\ []) do
    info
    |> cast(attrs, [
      :first_name,
      :last_name,
      :tshirt_size,
      :uin,
      :preferred_name,
      :phone_number,
      :graduation_year,
      :major,
      :gender,
      :age,
      :international_student,
      :ieee_membership_number
    ])
    |> validate_required([
      :first_name,
      :last_name,
      :tshirt_size,
      :graduation_year,
      :major,
      :gender,
      :international_student
    ])
    |> validate_uin(opts)
    |> validate_phone_number()
    |> validate_member_number()
    |> maybe_change_major_other(attrs)
    |> maybe_change_international_country(attrs)
    |> maybe_change_gender_other(attrs)
  end

  def validate_phone_number(changeset) do
    changeset
    |> validate_format(:phone_number, ~r/^\d{3}-\d{3}-\d{4}$/,
      message: "must be in the format XXX-XXX-XXXX"
    )
  end

  def validate_uin(changeset, _opts) do
    changeset
    |> validate_required([:uin])
    |> validate_number_regex(:uin, ~r/^\d{3}00\d{4}$/, message: "must be a valid UIN")
    |> unique_constraint(:uin)
  end

  def validate_member_number(changeset) do
    changeset
    # |> validate_required([:ieee_membership_number])
    |> validate_number_regex(:ieee_membership_number, ~r/^\d{8,9}$/,
      message: "must be a valid IEEE membership number"
    )

    # |> unique_constraint(:ieee_membership_number) # uncomment and make DB migration to add unique constraint?
  end

  def validate_number_regex(changeset, field, regex, opts \\ []) do
    changeset
    |> validate_change(field, fn ^field, number ->
      if Regex.match?(regex, to_string(number)) do
        []
      else
        [{field, Keyword.get(opts, :message, "is invalid")}]
      end
    end)
  end

  def maybe_change_major_other(changeset, attrs) do
    case get_field(changeset, :major) do
      :Other ->
        changeset
        |> cast(attrs, [:major_other])
        |> validate_required([:major_other])
        |> validate_length(:major_other, is: 4)
        |> validate_format(:major_other, ~r/^[A-Z]*$/, message: "must be all uppercase letters")
        |> validate_exclusion(
          :major_other,
          Ecto.Enum.values(__MODULE__, :major)
          |> Stream.map(&Atom.to_string/1),
          message: "only use \"Other\" if your major is not listed"
        )

      _ ->
        changeset
    end
  end

  def maybe_change_international_country(changeset, attrs) do
    case get_field(changeset, :international_student) do
      true ->
        changeset
        |> cast(attrs, [:international_country])
        |> validate_required([:international_country])

      _ ->
        changeset
    end
  end

  def maybe_change_gender_other(changeset, attrs) do
    case get_field(changeset, :gender) do
      :Other ->
        changeset
        |> cast(attrs, [:gender_other])

      # |> validate_required([:gender_other])

      _ ->
        changeset
    end
  end
end
