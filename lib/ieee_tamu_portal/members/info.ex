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
    field :major, Ecto.Enum, values: [:ecen, :cpen]
    field :phone_number, :string
    field :preferred_name, :string
    field :sex, Ecto.Enum, values: [:male, :female, :other]
    field :sex_other, :string
    field :tshirt_size, Ecto.Enum, values: [:s, :m, :l, :xl, :xxl]
    field :uin, :integer

    timestamps(type: :utc_datetime)
    belongs_to :member, IeeeTamuPortal.Accounts.Member
  end

  @doc false
  def changeset(info, attrs) do
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
      :sex,
      :sex_other,
      :age,
      :international_student,
      :international_country
    ])
    |> validate_required([
      :first_name,
      :last_name,
      :tshirt_size,
      :uin,
      :preferred_name,
      :phone_number,
      :graduation_year,
      :major,
      :sex,
      :sex_other,
      :age,
      :international_student,
      :international_country
    ])
    |> unique_constraint(:uin)
  end
end
