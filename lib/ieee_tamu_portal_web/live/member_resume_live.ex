defmodule IeeeTamuPortalWeb.MemberResumeLive do
  use IeeeTamuPortalWeb, :live_view

  alias Phoenix.LiveView.JS
  alias IeeeTamuPortalWeb.Upload.SimpleS3Upload
  alias IeeeTamuPortal.{Accounts, Members, Repo}

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Resume Drop
    </.header>

    <form id="member-form" phx-change="validate" phx-submit="save">
      <%= if @current_member.resume do %>
        <div class="flex justify-center items-center">
          <p class="text-gray-500">Current resume</p>
        </div>
        <div class="flex justify-center items-center">
          <iframe src={@resume_url} class="w-full h-96" />
        </div>
      <% else %>
        <div class="flex justify-center items-center">
          <p class="text-gray-500">No resume uploaded</p>
        </div>
      <% end %>
      <div class="flex border-t border-gray-200 pt-5 justify-evenly items-center">
        <%= for entry <- @uploads.member_resume.entries do %>
          <article class="upload-entry" phx-drop-target={@uploads.member_resume.ref}>
            <span class="upload-entry-name">{entry.client_name}</span>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              aria-label="cancel"
            >
              <.icon name="hero-x-mark" />
            </button>
          </article>
        <% end %>
        <%= if length(@uploads.member_resume.entries) < @uploads.member_resume.max_entries do %>
          <div class="mt-1 sm:mt-0 flex-grow" phx-drop-target={@uploads.member_resume.ref}>
            <div class="flex-col justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
              <div class="space-y-1 text-center">
                <.icon name="hero-document-text" />
                <div class="flex-col justify-center text-sm pb-4">
                  <p class="pb-2">Drag and drop your resume here, or</p>
                  <label
                    for={@uploads.member_resume.ref}
                    class="relative cursor-pointer rounded-md font-medium px-4 py-2 text-white bg-zinc-900 hover:bg-zinc-700 focus-within:ring-2 focus-within:ring-offset-1"
                  >
                    Choose file
                  </label>
                </div>
              </div>
              <div class="text-xs text-center text-gray-500">
                PDFs only | Max 5MB
              </div>
            </div>
          </div>
        <% end %>
        <.live_file_input upload={@uploads.member_resume} class="sr-only" tabindex="0" />
      </div>
      <div class="mt-2 flex items-center justify-between gap-6">
        <.button phx-disable-with="Uploading...">
          {if @current_member.resume do
            "Update"
          else
            "Upload"
          end}
        </.button>
        <.button :if={@current_member.resume} phx-click="delete_resume" phx-disable-with="Deleting...">
          Delete Current
        </.button>
      </div>
      <div class="mt-2 flex items-center justify-between gap-6"></div>
    </form>
    """
  end

  def mount(_params, _session, socket) do
    member =
      socket.assigns.current_member
      |> Repo.preload(:resume)

    # if member resume exists, sign a GET request for the resume
    resume_url =
      case member.resume do
        nil ->
          nil

        resume ->
          uri = uri(resume)
          {:ok, url} = SimpleS3Upload.presigned_get(uri: uri)
          url
      end

    socket =
      socket
      |> assign(:current_member, member)
      |> assign(:resume_url, resume_url)
      |> allow_upload(:member_resume,
        accept: ~w(.pdf),
        max_file_size: 5_000_000,
        max_entries: 1,
        external: &presign_upload/2
      )

    {:ok, socket}
  end

  def handle_event("validate", %{"_target" => ["member_resume"]}, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :member_resume, ref)}
  end

  def handle_event("save", _params, socket) do
    {:noreply, save_resume(socket)}
  end

  def handle_event("delete_resume", _params, socket) do
    {:noreply, delete_resume(socket)}
  end

  defp delete_resume(socket) do
    member = socket.assigns.current_member
    resume = member.resume

    # TODO: delete from S3

    # delete from DB
    Repo.delete(resume)

    member = %Accounts.Member{member | resume: nil}

    socket
    |> assign(:resume_url, nil)
    |> assign(:current_member, member)
    |> Phoenix.LiveView.put_flash(:info, "Resume deleted successfully")
  end

  defp save_resume(socket) do
    {completed, []} = uploaded_entries(socket, :member_resume)

    case completed do
      [] ->
        socket

      [entry] ->
        member = socket.assigns.current_member

        resume_changes =
          %{
            original_filename: entry.client_name,
            bucket_url: SimpleS3Upload.bucket_url(),
            key: key(member, entry)
          }

        resume = member.resume || %Members.Resume{member_id: member.id}

        changeset = Members.change_member_resume(resume, resume_changes)
        resume = Repo.insert_or_update!(changeset)

        member = %Accounts.Member{member | resume: resume}

        # sign the GET request for the resume
        {:ok, url} = SimpleS3Upload.presigned_get(key: resume.key)

        socket
        |> assign(:resume_url, url)
        |> cancel_upload(:member_resume, entry.ref)
        |> Phoenix.LiveView.put_flash(:info, "Resume uploaded successfully")
        |> assign(:current_member, member)
    end
  end

  defp key(member, entry) do
    filename = "#{member.id}-#{member.email}#{Path.extname(entry.client_name)}"
    "resumes/#{filename}"
  end

  defp uri(resume) do
    "#{resume.bucket_url}/#{URI.encode(resume.key)}"
  end

  defp presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    member = socket.assigns.current_member
    key = key(member, entry)

    {:ok, presigned_url} =
      SimpleS3Upload.presigned_put(
        key: key,
        content_type: entry.client_type,
        max_file_size: uploads[entry.upload_config].max_file_size
      )

    meta = %{
      uploader: "S3",
      key: key,
      url: presigned_url
    }

    {:ok, meta, socket}
  end

  def js_exec(js \\ %JS{}, to, call, args) do
    JS.dispatch(js, "js:exec", to: to, detail: %{call: call, args: args})
  end
end
