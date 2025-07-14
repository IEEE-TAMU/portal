defmodule IeeeTamuPortalWeb.AdminLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Accounts

  @impl true
  def mount(_params, _session, socket) do
    member_count = Accounts.count_members()

    socket =
      socket
      |> assign(:member_count, member_count)
      |> assign(:page_title, "Admin Dashboard")

    {:ok, socket, layout: {IeeeTamuPortalWeb.Layouts, :admin}}
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
              <p class="text-2xl font-bold text-gray-900"><%= @member_count %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                <.icon name="hero-check-circle" class="w-5 h-5 text-white" />
              </div>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Active Members</p>
              <p class="text-2xl font-bold text-gray-900">-</p>
              <p class="text-xs text-gray-500">Coming soon</p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                <.icon name="hero-document-text" class="w-5 h-5 text-white" />
              </div>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Resumes</p>
              <p class="text-2xl font-bold text-gray-900">-</p>
              <p class="text-xs text-gray-500">Coming soon</p>
            </div>
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

          <button class="p-4 border border-gray-300 rounded-lg hover:bg-gray-50 text-left">
            <div class="flex items-center">
              <.icon name="hero-document-arrow-down" class="w-5 h-5 text-gray-500 mr-3" />
              <span class="text-sm font-medium text-gray-700">Export Member Data</span>
            </div>
            <p class="text-xs text-gray-500 mt-1">Coming soon</p>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
