defmodule IeeeTamuPortalWeb.AdminCheckinLive do
  use IeeeTamuPortalWeb, :live_view

  @moduledoc """
  Admin page to scan member check-in QR codes and export check-ins.

  - Click Start Scanner to initialize the camera.
  - Hold the QR inside the green safe area.
  - Export CSV for all events in the current year or a single event.
  """

  alias Phoenix.PubSub
  alias IeeeTamuPortal.Settings
  alias IeeeTamuPortal.Members.EventCheckin

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(IeeeTamuPortal.PubSub, "checkins")
    end

    year = Settings.get_registration_year!()
    events = EventCheckin.list_event_names_for_year(year)

    {:ok,
     socket
     |> assign(:page_title, "Check-in")
     |> assign(:last_result, nil)
     |> assign(:status, :idle)
     |> assign(:error, nil)
     |> assign(:scanner_active, false)
     |> assign(:year, year)
     |> assign(:events, events)
     |> assign(:selected_event, "")}
  end

  @impl true
  def handle_event("qr_scanned", %{"content" => content}, socket) do
    member_id = extract_member_id(content)

    cond do
      is_nil(member_id) ->
        {:noreply, assign(socket, error: "Unrecognized QR", status: :error)}

      true ->
        {:noreply,
         socket
         |> push_event("perform_checkin", %{member_id: member_id})
         |> assign(:status, :checking)
         |> assign(:error, nil)
         |> assign(:last_result, "Scanning member #{member_id}...")}
    end
  end

  @impl true
  def handle_event("checkin_response", %{"ok" => true, "member_id" => _}, socket) do
    # Briefly show a full-screen success overlay; don't display internal IDs
    Process.send_after(self(), :clear_success, 1500)

    {:noreply,
     socket
     |> assign(:status, :success)
     |> assign(:last_result, "Checked In")}
  end

  def handle_event("checkin_response", %{"ok" => false, "member_id" => member_id}, socket) do
    {:noreply,
     socket
     |> assign(:status, :error)
     |> assign(:error, "Failed to check in member #{member_id}")}
  end

  @impl true
  def handle_event("restart", _params, socket) do
    {:noreply,
     socket
     |> assign(:status, :idle)
     |> assign(:error, nil)
     |> assign(:last_result, "Scanner reset")}
  end

  @impl true
  def handle_event("start_scanner", _params, socket) do
    {:noreply,
     socket
     |> assign(:scanner_active, true)
     |> push_event("start_scanner", %{})}
  end

  @impl true
  def handle_event("select_event", %{"event_name" => event}, socket) do
    {:noreply, assign(socket, :selected_event, event)}
  end

  @impl true
  def handle_info({:member_checked_in, _member_id}, socket) do
    {:noreply, assign(socket, :last_result, "Server confirmed check-in")}
  end

  @impl true
  def handle_info(:clear_success, socket) do
    {:noreply, assign(socket, :status, :idle)}
  end

  defp extract_member_id(content) when is_binary(content) do
    with true <- String.contains?(content, "/admin/check-in"),
         %URI{query: query} <- URI.parse(content),
         %{"member_id" => member_id} <- URI.decode_query(query) do
      member_id
    else
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <.icon name="hero-qr-code" class="w-7 h-7 text-indigo-600" /> Check-in
        </h1>
        <p class="text-gray-600 mt-1">
          Use your device camera to scan member check-in QR codes or export year check-ins.
        </p>
      </div>

      <div class="grid lg:grid-cols-3 gap-6 items-start">
        <div class="lg:col-span-2 space-y-4">
          <div class="w-full max-w-xl mx-auto relative">
            <div
              id="qr-container"
              phx-hook="QRScanner"
              class={[
                "relative w-full aspect-square bg-black rounded-lg overflow-hidden",
                not @scanner_active && "hidden"
              ]}
            >
              <video
                id="qr-video"
                phx-update="ignore"
                class="absolute inset-0 w-full h-full object-cover"
                playsinline
              >
              </video>
              <!-- Green safe area overlay -->
              <div :if={@scanner_active} class="pointer-events-none absolute inset-0">
                <div class="absolute inset-0 grid place-items-center">
                  <div class="w-2/3 aspect-square border-4 border-green-500/90 shadow-[0_0_40px_10px_rgba(34,197,94,0.25)_inset] rounded-lg">
                  </div>
                </div>
              </div>
              <div
                :if={@status == :checking}
                class="absolute inset-0 flex items-center justify-center bg-black/40"
              >
                <div class="text-white text-sm animate-pulse">Checking in...</div>
              </div>
            </div>
          </div>

          <div class="flex gap-2 flex-wrap">
            <button
              :if={!@scanner_active}
              phx-click="start_scanner"
              id="start-scan"
              class="px-4 py-2 bg-green-600 text-white rounded-md text-sm font-medium hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              Start Scanner
            </button>
            <button
              :if={@scanner_active}
              phx-click="restart"
              phx-hook="QRScanner"
              phx-update="ignore"
              id="restart-scan"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              Restart Scanner
            </button>
            <div id="toggle-flash-wrapper" class="hidden">
              <button
                id="toggle-flash"
                phx-update="ignore"
                class="px-4 py-2 bg-gray-600 text-white rounded-md text-sm font-medium hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500"
              >
                Toggle Flash
              </button>
            </div>
            <label id="camera-select-wrapper" for="camera-select" class="hidden">
              Camera Source
              <select
                id="camera-select"
                phx-update="ignore"
                class="px-3 py-2 border border-gray-300 rounded-md text-sm"
              >
              </select>
            </label>
          </div>
        </div>

        <div class="space-y-4">
          <div class="bg-white p-4 rounded-lg shadow">
            <h2 class="text-lg font-semibold mb-2">Status</h2>
            <p class={status_color(@status)}>{@last_result || "Idle"}</p>
            <p :if={@error} class="text-red-600 text-sm mt-2">{@error}</p>
          </div>

          <div class="bg-white p-4 rounded-lg shadow">
            <h2 class="text-lg font-semibold mb-2">Export Check-ins</h2>
            <p class="text-sm text-gray-600 mb-2">Year: <span class="font-medium">{@year}</span></p>
            <.form for={%{}} phx-change="select_event" class="space-y-2">
              <label class="block text-sm">
                <span class="text-gray-700">Event (optional)</span>
                <select name="event_name" class="mt-1 block w-full border-gray-300 rounded-md">
                  <option value="">All events</option>
                  <%= for ev <- @events do %>
                    <option value={ev} selected={@selected_event == ev}>{ev}</option>
                  <% end %>
                </select>
              </label>
            </.form>
            <.link
              href={~p"/admin/download-checkins?#{[event_name: @selected_event]}"}
              class="inline-flex items-center px-3 py-2 mt-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
            >
              <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download CSV
            </.link>
          </div>

          <div class="bg-white p-4 rounded-lg shadow">
            <h2 class="text-lg font-semibold mb-2">Instructions</h2>
            <ol class="list-decimal list-inside text-sm text-gray-600 space-y-1">
              <li>Click "Start Scanner" to initialize the camera.</li>
              <li>Hold the member QR inside the green square.</li>
              <li>On success, you'll see confirmation here.</li>
              <li>If lighting is poor, enable device flash.</li>
            </ol>
          </div>
        </div>
      </div>
      <!-- Full-screen success overlay -->
      <div
        :if={@status == :success}
        class="fixed inset-0 z-50 flex items-center justify-center bg-green-600/90"
      >
        <div class="text-white text-5xl md:text-7xl font-extrabold tracking-wide drop-shadow-lg">
          Checked In
        </div>
      </div>
    </div>
    """
  end

  defp status_color(:idle), do: "text-gray-500"
  defp status_color(:checking), do: "text-amber-600"
  defp status_color(:success), do: "text-green-600"
  defp status_color(:error), do: "text-red-600"
  defp status_color(_), do: "text-gray-500"
end
