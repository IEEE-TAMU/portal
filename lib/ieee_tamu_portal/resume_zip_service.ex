defmodule IeeeTamuPortal.ResumeZipService do
  @moduledoc """
  Service for streaming zip files of member resumes directly to the client.

  This service uses Zstream to create zip files on-the-fly without storing
  any temporary files on disk, providing memory-efficient streaming of
  resume downloads directly from S3 to the client.
  """

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Members.Resume

  @doc """
  Creates a streaming zip response containing member resumes.

  Options:
    * `:looking_for` - filter by `:full_time` or `:internship`. Defaults to `:all`.
      When filtering, members marked `:either` are included in both subsets.
  Returns a Stream that can be used directly in Phoenix responses.
  """
  def stream_zip(opts \\ []) do
    looking_for = Keyword.get(opts, :looking_for, :all)

    case get_members_with_resumes(looking_for) do
      [] ->
        {:error, :no_resumes_found}

      members ->
        short_date = Date.utc_today() |> to_string()

        filter_suffix =
          case looking_for do
            :full_time -> "_full_time"
            :internship -> "_internship"
            _ -> ""
          end

        folder_name = "ieee_tamu_resumes#{filter_suffix}_#{short_date}"

        zip_stream =
          members
          |> Stream.map(&create_zip_entry(&1, folder_name))
          |> Stream.filter(&(&1 != nil))
          |> Zstream.zip()

        {:ok, zip_stream}
    end
  end

  @doc """
  Gets the count of members with resumes for display purposes.
  """
  def count_resumes() do
    get_members_with_resumes(:all) |> length()
  end

  def count_resumes(filter) when filter in [:full_time, :internship] do
    get_members_with_resumes(filter) |> length()
  end

  # Private functions

  defp get_members_with_resumes(filter) do
    Accounts.list_members()
    |> Enum.filter(& &1.resume)
    |> IeeeTamuPortal.Repo.preload([:info])
    |> Enum.filter(fn member ->
      case filter do
        :all -> true
        :full_time -> member.resume.looking_for in [:full_time, :either]
        :internship -> member.resume.looking_for in [:internship, :either]
        _ -> true
      end
    end)
  end

  defp create_zip_entry(member, folder_name) do
    try do
      case fetch_resume_content(member) do
        {:ok, content} ->
          filename = create_safe_filename(member)
          Zstream.entry(Path.join(folder_name, filename), [content])

        {:error, reason} ->
          # Log error but continue with other resumes
          require Logger
          Logger.warning("Failed to fetch resume for #{member.email}: #{inspect(reason)}")
          nil
      end
    rescue
      error ->
        require Logger
        Logger.error("Exception processing resume for #{member.email}: #{inspect(error)}")
        nil
    end
  end

  defp fetch_resume_content(member) do
    with {:ok, signed_url} <-
           Resume.signed_url(member.resume,
             method: "GET",
             response_content_type: "application/pdf"
           ),
         {:ok, response} <- make_http_request(signed_url) do
      {:ok, response}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  defp make_http_request(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_safe_filename(member) do
    case member.info do
      nil ->
        # Fallback to email prefix if no info available
        email_prefix = String.split(member.email, "@") |> List.first()
        safe_prefix = String.replace(email_prefix, ~r/[^a-zA-Z0-9._-]/, "_")
        "#{safe_prefix}.pdf"

      info ->
        # Use preferred_name if available, otherwise use first_name
        display_name =
          if info.preferred_name && String.trim(info.preferred_name) != "" do
            sanitize_filename_part(info.preferred_name)
          else
            sanitize_filename_part(info.first_name)
          end

        last_name = sanitize_filename_part(info.last_name)

        if display_name && last_name do
          "#{String.downcase(display_name)}_#{String.downcase(last_name)}.pdf"
        else
          # Fallback to email prefix
          email_prefix = String.split(member.email, "@") |> List.first()
          safe_prefix = String.replace(email_prefix, ~r/[^a-zA-Z0-9._-]/, "_")
          "#{safe_prefix}.pdf"
        end
    end
  end

  defp sanitize_filename_part(nil), do: nil

  defp sanitize_filename_part(name) when is_binary(name) do
    sanitized = String.replace(name, ~r/[^a-zA-Z0-9._-]/, "_")
    if String.trim(sanitized) == "", do: nil, else: sanitized
  end
end
