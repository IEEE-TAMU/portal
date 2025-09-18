defmodule IeeeTamuPortal.Members.Resume do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resumes" do
    field :original_filename, :string

    field :bucket_url, :string,
      autogenerate: {IeeeTamuPortalWeb.Upload.SimpleS3Upload, :bucket_url, []}

    field :key, :string
    field :looking_for, Ecto.Enum, values: [:full_time, :internship, :either], default: :either

    timestamps(type: :utc_datetime)
    belongs_to :member, IeeeTamuPortal.Accounts.Member
  end

  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [:original_filename, :bucket_url, :key, :looking_for])
    |> validate_required([:original_filename, :key, :looking_for])
    |> unique_constraint(:member_id)
  end

  defp uri(resume) do
    "#{resume.bucket_url}/#{URI.encode(resume.key)}"
  end

  def count do
    IeeeTamuPortal.Repo.aggregate(IeeeTamuPortal.Members.Resume, :count, :id)
  end

  def signed_url(opts) when is_list(opts) do
    opts = Keyword.put_new(opts, :method, "PUT")
    IeeeTamuPortalWeb.Upload.SimpleS3Upload.sign(opts)
  end

  def signed_url(resume = %__MODULE__{}, opts \\ []) do
    opts = Keyword.put_new(opts, :method, "GET")
    opts = Keyword.put_new(opts, :uri, uri(resume))
    IeeeTamuPortalWeb.Upload.SimpleS3Upload.sign(opts)
  end

  def delete(resume) do
    :ok = IeeeTamuPortal.S3Delete.delete_object(IeeeTamuPortal.S3Delete, uri(resume))
    IeeeTamuPortal.Repo.delete(resume)
  end

  def key(%IeeeTamuPortal.Accounts.Member{} = member, %Phoenix.LiveView.UploadEntry{} = entry) do
    filename = "#{member.id}-#{member.email}#{Path.extname(entry.client_name)}"
    "resumes/#{filename}"
  end
end
