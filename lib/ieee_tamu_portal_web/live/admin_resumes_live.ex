defmodule IeeeTamuPortalWeb.AdminResumesLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.ResumeZipService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:total_count, ResumeZipService.count_resumes())
     |> assign(:full_time_count, ResumeZipService.count_resumes(:full_time))
     |> assign(:internship_count, ResumeZipService.count_resumes(:internship))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <.header>
        Resumes
        <:subtitle>Download member resumes as ZIP archives</:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="p-4 rounded-lg border bg-white">
          <p class="text-sm text-gray-600">All Resumes</p>
          <p class="text-2xl font-semibold">{@total_count}</p>
          <.link
            :if={@total_count > 0}
            href={~p"/admin/download-resumes"}
            class="mt-3 inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700"
          >
            <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download All
          </.link>
        </div>

        <div class="p-4 rounded-lg border bg-white">
          <p class="text-sm text-gray-600">Full-Time</p>
          <p class="text-2xl font-semibold">{@full_time_count}</p>
          <.link
            :if={@full_time_count > 0}
            href={~p"/admin/download-resumes?#{[looking_for: "full_time"]}"}
            class="mt-3 inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700"
          >
            <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download Full-Time
          </.link>
        </div>

        <div class="p-4 rounded-lg border bg-white">
          <p class="text-sm text-gray-600">Internship</p>
          <p class="text-2xl font-semibold">{@internship_count}</p>
          <.link
            :if={@internship_count > 0}
            href={~p"/admin/download-resumes?#{[looking_for: "internship"]}"}
            class="mt-3 inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700"
          >
            <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download Internship
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
