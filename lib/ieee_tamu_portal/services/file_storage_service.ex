defmodule IeeeTamuPortal.Services.FileStorageService do
  @moduledoc """
  Service layer for managing file storage operations.

  This service abstracts file storage operations like upload, download, and deletion
  from the domain models and provides a clean interface for the web layer.
  It handles S3 integration and resume management.
  """

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortal.Members.Resume

  @doc """
  Uploads a resume for a member.

  This function handles the creation of a resume record with the appropriate
  S3 key and metadata for the uploaded file.

  ## Parameters

  - `member` - The member struct
  - `upload_entry` - Phoenix upload entry containing file information

  ## Examples

      iex> upload_resume(member, upload_entry)
      {:ok, %Resume{}}
      
      iex> upload_resume(member, invalid_entry)
      {:error, %Ecto.Changeset{}}
  """
  def upload_resume(member, upload_entry)
      when is_struct(upload_entry, Phoenix.LiveView.UploadEntry) do
    key = Resume.key(member, upload_entry)

    resume_attrs = %{
      original_filename: upload_entry.client_name,
      key: key
    }

    Members.create_member_resume(member, resume_attrs)
  end

  def upload_resume(member, upload_params) when is_map(upload_params) do
    # Handle simple map format for testing
    key = generate_simple_key(member, upload_params[:client_name] || "")

    resume_attrs = %{
      original_filename: upload_params[:client_name] || "",
      key: key
    }

    Members.create_member_resume(member, resume_attrs)
  end

  @doc """
  Deletes a resume and its associated file from storage.

  This function handles both the S3 deletion and database record removal.

  ## Parameters

  - `resume` - The resume struct to delete

  ## Examples

      iex> delete_resume(resume)
      {:ok, %Resume{}}
      
      iex> delete_resume(invalid_resume)
      {:error, reason}
  """
  def delete_resume(resume) do
    try do
      Resume.delete(resume)
    rescue
      Ecto.StaleEntryError ->
        {:error, :not_found}
    end
  end

  @doc """
  Generates a signed URL for accessing a resume.

  ## Parameters

  - `resume` - The resume struct
  - `opts` - Options for URL generation (optional)

  ## Examples

      iex> get_resume_url(resume)
      {:ok, "https://signed-url..."}
      
      iex> get_resume_url(resume, method: "GET", response_content_type: "application/pdf")
      {:ok, "https://signed-url..."}
  """
  def get_resume_url(resume, opts \\ []) do
    try do
      Resume.signed_url(resume, opts)
    rescue
      ArgumentError ->
        {:error, :configuration_missing}
    end
  end

  @doc """
  Generates a unique S3 key for a resume upload.

  The key includes the member ID and email for uniqueness and traceability.

  ## Parameters

  - `member` - The member struct
  - `upload_entry` - Upload entry containing file information

  ## Examples

      iex> generate_resume_key(member, upload_entry)
      "resumes/123-member@example.com.pdf"
  """
  def generate_resume_key(member, upload_entry)
      when is_struct(upload_entry, Phoenix.LiveView.UploadEntry) do
    Resume.key(member, upload_entry)
  end

  def generate_resume_key(member, upload_params) when is_map(upload_params) do
    generate_simple_key(member, upload_params[:client_name] || "")
  end

  # Private helper for simple key generation in tests
  defp generate_simple_key(member, filename) do
    extension = Path.extname(filename)
    sanitized_email = String.replace(member.email, ~r/[^a-zA-Z0-9@.]/, "")
    "resumes/#{member.id}-#{sanitized_email}#{extension}"
  end
end
