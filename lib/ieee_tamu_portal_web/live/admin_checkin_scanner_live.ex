defmodule IeeeTamuPortalWeb.AdminCheckinScannerLive do
  use IeeeTamuPortalWeb, :live_view

  @moduledoc """
  LiveView that opens the admin user's camera and scans member check-in QR codes.

  The member QR codes already point at `/admin/check-in?member_id=<id>`.
  We simply detect that URL, extract the `member_id` (string or int) and
  POST (GET in current controller impl) to the existing controller endpoint
  to perform the check-in, then show feedback.
  """

  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(IeeeTamuPortal.PubSub, "checkins")
    end

    {:ok,
     socket
     |> assign(:page_title, "Check-in Scanner")
     |> assign(:last_result, nil)
     |> assign(:status, :idle)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("qr_scanned", %{"content" => content}, socket) do
    # Expect full URL like https://.../admin/check-in?member_id=123
    member_id = extract_member_id(content)

    cond do
      is_nil(member_id) ->
        {:noreply, assign(socket, error: "Unrecognized QR", status: :error)}

      true ->
        # Fire off request via JS fetch (simpler) - we just update UI optimistically.
        {:noreply,
         socket
         |> push_event("perform_checkin", %{member_id: member_id})
         |> assign(:status, :checking)
         |> assign(:error, nil)
         |> assign(:last_result, "Scanning member #{member_id}...")}
    end
  end

  @impl true
  def handle_event("checkin_response", %{"ok" => true, "member_id" => member_id}, socket) do
    {:noreply,
     socket
     |> assign(:status, :success)
     |> assign(:last_result, "Checked in member #{member_id}")}
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
  def handle_info({:member_checked_in, member_id}, socket) do
    # Broadcast comes from controller; we can show a subtle confirmation if matching last op.
    {:noreply, assign(socket, :last_result, "Server confirmed check-in for #{member_id}")}
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
          <.icon name="hero-qr-code" class="w-7 h-7 text-indigo-600" /> Check-in Scanner
        </h1>
        <p class="text-gray-600 mt-1">Use your device camera to scan member check-in QR codes.</p>
      </div>

      <div class="grid lg:grid-cols-3 gap-6 items-start">
        <div class="lg:col-span-2 space-y-4">
          <div class="w-full max-w-xl mx-auto relative">
            <div class="relative w-full aspect-square bg-black rounded-lg overflow-hidden">
              <video
                id="qr-video"
                phx-update="ignore"
                class="absolute inset-0 w-full h-full object-cover"
                playsinline
              >
              </video>
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
              phx-click="restart"
              phx-hook="QRScanner"
              phx-update="ignore"
              id="restart-scan"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              Restart Scanner
            </button>
            <button
              id="toggle-flash"
              phx-update="ignore"
              class="px-4 py-2 bg-gray-600 text-white rounded-md text-sm font-medium hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500"
            >
              Toggle Flash
            </button>
            <select
              id="camera-select"
              phx-update="ignore"
              class="px-3 py-2 border border-gray-300 rounded-md text-sm"
            >
            </select>
          </div>
        </div>

        <div class="space-y-4">
          <div class="bg-white p-4 rounded-lg shadow">
            <h2 class="text-lg font-semibold mb-2">Status</h2>
            <p class={status_color(@status)}>{@last_result || "Idle"}</p>
            <p :if={@error} class="text-red-600 text-sm mt-2">{@error}</p>
          </div>

          <div class="bg-white p-4 rounded-lg shadow">
            <h2 class="text-lg font-semibold mb-2">Instructions</h2>
            <ol class="list-decimal list-inside text-sm text-gray-600 space-y-1">
              <li>Hold the member QR inside the green square.</li>
              <li>Wait for automatic detection; no need to tap.</li>
              <li>On success, you'll see confirmation here.</li>
              <li>If lighting is poor, enable device flash.</li>
            </ol>
          </div>
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
