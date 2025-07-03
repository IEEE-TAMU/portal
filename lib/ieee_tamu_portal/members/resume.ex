defmodule IeeeTamuPortal.Members.Resume do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resumes" do
    field :original_filename, :string
    field :bucket_url, :string
    field :key, :string

    timestamps(type: :utc_datetime)
    belongs_to :member, IeeeTamuPortal.Accounts.Member
  end

  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [:original_filename, :bucket_url, :key])
    |> validate_required([:original_filename, :bucket_url, :key])
  end

  def uri(resume) do
    "#{resume.bucket_url}/#{URI.encode(resume.key)}"
  end
end
