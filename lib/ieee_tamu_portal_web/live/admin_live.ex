defmodule IeeeTamuPortalWeb.AdminLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Accounts, Members, Settings, Api}

  @impl true
  def mount(_params, _session, socket) do
    member_count = Accounts.count_members()
    paid_members_count = paid_members_count()
    resume_count = Members.Resume.count()
    api_key_count = length(Api.list_api_keys())

    socket =
      socket
      |> assign(:member_count, member_count)
      |> assign(:paid_members_count, paid_members_count)
      |> assign(:resume_count, resume_count)
      |> assign(:api_key_count, api_key_count)
      |> assign(:page_title, "Admin Dashboard")

    {:ok, socket}
  end

  defp paid_members_count do
    try do
      current_year = Settings.get_registration_year!()
      Members.Registration.paid_members_count_for_year(current_year)
    rescue
      _ -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p class="text-gray-600 mt-2">Overview of the IEEE TAMU Portal</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                <.icon name="hero-users" class="w-5 h-5 text-white" />
              </div>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Members</p>
              <p class="text-2xl font-bold text-gray-900">{@member_count}</p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                <.icon name="hero-credit-card" class="w-5 h-5 text-white" />
              </div>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Paid Members</p>
              <p class="text-2xl font-bold text-gray-900">{@paid_members_count}</p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                  <.icon name="hero-document-text" class="w-5 h-5 text-white" />
                </div>
              </div>

              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Uploaded Resumes</p>
                <p class="text-2xl font-bold text-gray-900">{@resume_count}</p>
              </div>
            </div>
            <%= if @resume_count > 0 do %>
              <div class="flex-shrink-0">
                <.link
                  href={~p"/admin/download-resumes"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="mt-8 bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <button class="p-4 border border-gray-300 rounded-lg hover:bg-gray-50 text-left">
            <div class="flex items-center">
              <.icon name="hero-envelope" class="w-5 h-5 text-gray-500 mr-3" />
              <span class="text-sm font-medium text-gray-700">Send Email Notification</span>
            </div>
            <p class="text-xs text-gray-500 mt-1">Coming soon</p>
          </button>

          <.link
            navigate={~p"/admin/settings"}
            class="p-4 border border-gray-300 rounded-lg hover:bg-gray-50 text-left block"
          >
            <div class="flex items-center">
              <.icon name="hero-cog-6-tooth" class="w-5 h-5 text-gray-500 mr-3" />
              <span class="text-sm font-medium text-gray-700">Global Settings</span>
            </div>
            <p class="text-xs text-gray-500 mt-1">Manage application-wide settings</p>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
