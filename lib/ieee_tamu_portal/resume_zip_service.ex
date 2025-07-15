defmodule IeeeTamuPortal.ResumeZipService do
  @moduledoc """
  GenServer for creating zip files of member resumes in a resource-efficient way.

  This service handles:
  - Fetching all members with resumes
  - Signing S3 URLs for each resume
  - Streaming resume files from S3
  - Creating a zip file without loading everything into memory
  - Cleanup of temporary files
  """
  use GenServer

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Members.Resume
  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload

  @temp_dir "/tmp/resume_zips"

  defstruct [:zip_path, :members_with_resumes, :status, :requester_pid, :created_at]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a zip file containing all member resumes.
  Returns {:ok, zip_path} or {:error, reason}
  """
  def create_zip(requester_pid \\ self()) do
    GenServer.call(__MODULE__, {:create_zip, requester_pid}, :timer.minutes(5))
  end

  @doc """
  Gets the status of the current zip operation
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Cleans up a zip file after download
  """
  def cleanup_zip(zip_path) do
    GenServer.cast(__MODULE__, {:cleanup_zip, zip_path})
  end

  # Server callbacks
  
  def init(_opts) do
    # Ensure temp directory exists
    File.mkdir_p(@temp_dir)
    
    # Schedule cleanup of old files every hour
    Process.send_after(self(), :cleanup_old_files, :timer.hours(1))
    
    {:ok, %__MODULE__{status: :idle}}
  end

  def handle_call({:create_zip, requester_pid}, _from, state) do
    case state.status do
      :idle ->
        # Start the zip creation process
        task = Task.async(fn -> create_zip_file(requester_pid) end)

        new_state = %{
          state
          | status: :creating,
            requester_pid: requester_pid,
            created_at: DateTime.utc_now()
        }

        # Wait for the task to complete
        case Task.await(task, :timer.minutes(5)) do
          {:ok, zip_path} ->
            final_state = %{new_state | zip_path: zip_path, status: :ready}
            {:reply, {:ok, zip_path}, final_state}

          {:error, reason} ->
            final_state = %{new_state | status: :error}
            {:reply, {:error, reason}, final_state}
        end

      :creating ->
        {:reply, {:error, :already_creating}, state}

      :ready ->
        {:reply, {:ok, state.zip_path}, state}

      :error ->
        {:reply, {:error, :previous_error}, state}
    end
  end

  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_cast({:cleanup_zip, zip_path}, state) do
    if File.exists?(zip_path) do
      File.rm(zip_path)
    end

    new_state = %{state | status: :idle, zip_path: nil, requester_pid: nil}
    {:noreply, new_state}
  end

  def handle_info(:cleanup_old_files, state) do
    # Clean up files older than 1 hour
    cleanup_old_files()

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_files, :timer.hours(1))

    {:noreply, state}
  end

  # Private functions

  defp create_zip_file(_requester_pid) do
    try do
      # Get all members with resumes
      members = Accounts.list_members()
      members_with_resumes = Enum.filter(members, & &1.resume)

      if Enum.empty?(members_with_resumes) do
        {:error, :no_resumes_found}
      else
        # Create unique zip file name
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        zip_filename = "member_resumes_#{timestamp}.zip"
        zip_path = Path.join(@temp_dir, zip_filename)

        # Create zip file with streaming
        create_zip_with_streaming(members_with_resumes, zip_path)

        {:ok, zip_path}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp create_zip_with_streaming(members, zip_path) do
    # Prepare file entries for zip creation
    file_entries =
      Enum.map(members, fn member ->
        case process_member_resume(member) do
          {:ok, filename, content} ->
            {String.to_charlist(filename), content}

          {:error, reason} ->
            # Log error but continue with other resumes
            IO.puts("Failed to process resume for #{member.email}: #{inspect(reason)}")
            nil
        end
      end)
      # Remove nil entries
      |> Enum.filter(& &1)

    # Create zip file
    case :zip.create(String.to_charlist(zip_path), file_entries) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create zip: #{inspect(reason)}"
    end
  end

  defp process_member_resume(member) do
    try do
      # Sign the S3 URL
      {:ok, signed_url} =
        SimpleS3Upload.sign(
          method: "GET",
          uri: Resume.uri(member.resume),
          response_content_type: "application/pdf"
        )

      # Download the resume content using :httpc
      case :httpc.request(:get, {String.to_charlist(signed_url), []}, [{:timeout, 30_000}], [
             {:body_format, :binary}
           ]) do
        {:ok, {{_, 200, _}, _headers, body}} ->
          # Create safe filename
          safe_email = String.replace(member.email, ~r/[^a-zA-Z0-9._-]/, "_")
          filename = "#{safe_email}_resume.pdf"

          {:ok, filename, body}

        {:ok, {{_, status, _}, _headers, _body}} ->
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp cleanup_old_files do
    case File.ls(@temp_dir) do
      {:ok, files} ->
        cutoff_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

        Enum.each(files, fn file ->
          file_path = Path.join(@temp_dir, file)

          case File.stat(file_path) do
            {:ok, %File.Stat{mtime: mtime}} ->
              file_datetime = NaiveDateTime.from_erl!(mtime) |> DateTime.from_naive!("Etc/UTC")

              if DateTime.before?(file_datetime, cutoff_time) do
                File.rm(file_path)
              end

            _ ->
              :ok
          end
        end)

      _ ->
        :ok
    end
  end

end
