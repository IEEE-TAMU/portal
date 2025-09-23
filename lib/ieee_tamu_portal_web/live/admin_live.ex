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

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.stats_card
          label="Total Members"
          value={@member_count}
          icon="hero-users"
          icon_bg="bg-blue-500"
          action_href={~p"/admin/download-members"}
          action_label="CSV"
          action_class="bg-blue-600 hover:bg-blue-700 focus:ring-blue-500"
        />
        <.stats_card
          label="Paid Members"
          value={@paid_members_count}
          icon="hero-credit-card"
          icon_bg="bg-green-500"
          action_href={~p"/admin/download-members?paid=true"}
          action_label="CSV"
          action_class="bg-green-600 hover:bg-green-700 focus:ring-green-500"
        />
        <.stats_card
          label="Resumes"
          value={@resume_count}
          icon="hero-document-text"
          icon_bg="bg-purple-500"
          show_action={@resume_count > 0}
        >
          <:action :if={@resume_count > 0}>
            <.link
              href={~p"/admin/download-resumes"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
            >
              <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download
            </.link>
          </:action>
        </.stats_card>
      </div>

      <div class="mt-8 bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.quick_action_card
            title="Global Settings"
            description="Manage application-wide settings"
            icon="hero-cog-6-tooth"
            href={~p"/admin/settings"}
          />

          <.quick_action_card
            title="Events"
            description="Create and manage events"
            icon="hero-calendar-days"
            href={~p"/admin/events"}
          />

          <.quick_action_card
            title="API Keys"
            description="Manage API access keys"
            icon="hero-key"
            href={~p"/admin/api-keys"}
          />

          <.quick_action_card
            title="Resumes"
            description="Browse and manage resumes"
            icon="hero-document-text"
            href={~p"/admin/resumes"}
          />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Compact statistic card with an icon, label, value, and optional action link/button.

  ## Assigns

    * `:label` - short descriptor shown under/next to the value
    * `:value` - the primary number/text to surface (any renderable)
    * `:icon` - hero icon name (e.g. "hero-users")
    * `:icon_bg` - Tailwind utility classes for icon circle background (default blue)
    * `:value_class` - optional classes to override value style
    * `:action_href` - optional URL for an action link (e.g. download)
    * `:action_label` - text for the action (default: "Action")
    * `:action_icon` - hero icon for the action (default: hero-arrow-down-tray)
    * `:action_class` - Tailwind classes for the action control
    * `:show_action` - boolean (default true) to conditionally hide while keeping assigns

  You may also provide a custom action via the `:action` slot which overrides
  the generated link when present.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, default: "bg-blue-500"
  attr :value_class, :string, default: nil
  attr :action_href, :string, default: nil
  attr :action_label, :string, default: "Action"
  attr :action_icon, :string, default: "hero-arrow-down-tray"
  attr :action_class, :string, default: nil
  attr :show_action, :boolean, default: true
  slot :action

  def stats_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between gap-4 flex-wrap sm:flex-nowrap">
        <div class="flex items-center min-w-0">
          <div class="flex-shrink-0">
            <div class={[
              "w-8 h-8 rounded-full flex items-center justify-center text-white",
              @icon_bg
            ]}>
              <.icon name={@icon} class="w-5 h-5" />
            </div>
          </div>
          <div class="ml-4 min-w-0">
            <p class="text-sm font-medium text-gray-600 truncate">{@label}</p>
            <p class={[
              "text-2xl font-bold text-gray-900 whitespace-nowrap",
              @value_class
            ]}>
              {@value}
            </p>
          </div>
        </div>
        <div
          :if={@show_action && (@action != [] or @action_href)}
          class="w-full sm:w-auto mt-4 sm:mt-0 sm:ml-4 flex-shrink-0"
        >
          <%= if @action != [] do %>
            {render_slot(@action)}
          <% else %>
            <.link
              :if={@action_href}
              href={@action_href}
              download
              class={[
                "inline-flex items-center justify-center px-3 py-2 w-full sm:w-auto border border-transparent text-sm leading-4 font-medium rounded-md text-white focus:outline-none focus:ring-2 focus:ring-offset-2",
                @action_class || "bg-blue-600 hover:bg-blue-700 focus:ring-blue-500"
              ]}
            >
              <.icon name={@action_icon} class="w-4 h-4 mr-2" /> {@action_label}
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Quick action card for navigation to admin functions.

  ## Assigns

    * `:title` - the main title/label for the action
    * `:description` - a brief description of what the action does
    * `:icon` - hero icon name (e.g. "hero-cog-6-tooth")
    * `:href` - the URL to navigate to when clicked
    * `:disabled` - boolean to disable the action (default: false)

  """
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :href, :string, required: true
  attr :disabled, :boolean, default: false

  def quick_action_card(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "p-4 border border-gray-300 rounded-lg text-left block",
        if(@disabled, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50")
      ]}
    >
      <div class="flex items-center">
        <.icon name={@icon} class="w-5 h-5 text-gray-500 mr-3" />
        <span class="text-sm font-medium text-gray-700">{@title}</span>
      </div>
      <p class="text-xs text-gray-500 mt-1">{@description}</p>
    </.link>
    """
  end
end
