defmodule IeeeTamuPortalWeb.MemberResumeLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortal.Members.Resume

  @impl true
  def mount(_params, _session, socket) do
    member = Accounts.preload_member_resume(socket.assigns.current_member)

    # if member resume exists, sign a GET request for the resume
    resume_url =
      case member.resume do
        nil ->
          nil

        resume ->
          {:ok, url} =
            Resume.signed_url(resume, method: "GET", response_content_type: "application/pdf")

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

  defp presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    member = socket.assigns.current_member

    {:ok, presigned_url} =
      Resume.signed_url(
        method: "PUT",
        key: Resume.key(member, entry),
        content_type: entry.client_type,
        max_file_size: uploads[entry.upload_config].max_file_size
      )

    meta = %{
      uploader: "S3",
      # key: key,
      url: presigned_url
    }

    {:ok, meta, socket}
  end

  @impl true
  def handle_event("validate", %{"_target" => ["member_resume"]}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :member_resume, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    {completed, []} = uploaded_entries(socket, :member_resume)

    socket =
      case completed do
        [] ->
          socket

        [entry] ->
          {:ok, member} =
            socket.assigns.current_member
            |> Accounts.Member.put_resume(entry)

          # sign the GET request for the resume
          {:ok, url} =
            Resume.signed_url(member.resume,
              method: "GET",
              response_content_type: "application/pdf"
            )

          socket
          |> assign(:current_member, member)
          |> assign(:resume_url, url)
          |> cancel_upload(:member_resume, entry.ref)
          |> Phoenix.LiveView.put_flash(:info, "Resume uploaded successfully")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_resume", _params, socket) do
    {:ok, member} =
      socket.assigns.current_member
      |> Accounts.Member.delete_resume()

    socket =
      socket
      |> assign(:current_member, member)
      |> assign(:resume_url, nil)
      |> Phoenix.LiveView.put_flash(:info, "Resume deleted successfully")

    {:noreply, socket}
  end

  @impl true
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
          <embed src={@resume_url} type="application/pdf" class="w-full h-96"></embed>
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
end
