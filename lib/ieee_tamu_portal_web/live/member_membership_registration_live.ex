defmodule IeeeTamuPortalWeb.MemberMembershipRegistrationLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Settings, Members}
  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Accounts.Member

  @impl true
  def mount(_params, _session, socket) do
    current_member = socket.assigns.current_member

    # Get current registration year from settings
    current_year = Settings.get_registration_year!()
    default_tz = Application.get_env(:ieee_tamu_portal, :default_time_zone, "America/Chicago")

    time_zone =
      if connected?(socket),
        do: get_connect_params(socket)["timeZone"] || default_tz,
        else: default_tz

    # Look for existing registration for this member in the current year
    registration =
      case Members.get_registration(current_member.id, current_year) do
        nil ->
          {:ok, registration} = Members.create_registration(current_member, %{year: current_year})
          registration

        registration ->
          registration
      end
      |> Members.get_registration_with_payment()

    paid? = Members.Registration.payment_complete?(registration)
    status = if paid?, do: :paid, else: :pending

    # Build QR code or show message depending on check-in state
    current_event = Settings.get_current_event!()
    already_checked_in? = Member.member_is_checked_in?(current_member.id)

    checkin_qr_svg =
      if paid? and not already_checked_in? and is_binary(current_event) and
           current_event != IeeeTamuPortal.Settings.default_current_event() do
        url = url(~p"/admin/check-in?member_id=#{current_member.id}")
        EQRCode.encode(url) |> EQRCode.svg()
      else
        nil
      end

    # Compute next week's events (upcoming/ongoing limited to next 7 days)
    now = DateTime.utc_now()
    week_end = DateTime.add(now, 7 * 24 * 3600, :second)

    upcoming_week_events =
      Events.list_events()
      |> Enum.filter(fn e ->
        e.dtstart && DateTime.compare(e.dtstart, week_end) in [:lt, :eq]
      end)
      |> Enum.sort(fn a, b ->
        DateTime.compare(a.dtstart, b.dtstart) != :gt
      end)
      |> Enum.map(fn event ->
        rsvp_info = Events.get_event_with_rsvp_info(event.uid, current_member.id)
        Map.put(event, :rsvp_info, rsvp_info)
      end)

    socket =
      socket
      |> assign(:registration, registration)
      |> assign(:current_year, current_year)
      |> assign(:status, status)
      |> assign(:current_event, current_event)
      |> assign(:already_checked_in?, already_checked_in?)
      |> assign(:checkin_qr_svg, checkin_qr_svg)
      |> assign(:time_zone, time_zone)
      |> assign(:upcoming_week_events, upcoming_week_events)
      |> assign(:show_upcoming_events, false)
      |> assign(:rsvp_modal_open, false)
      |> assign(:selected_event, nil)

    if connected?(socket) and not already_checked_in? do
      Phoenix.PubSub.subscribe(IeeeTamuPortal.PubSub, "checkins")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("copy_confirmation_code", %{"code" => _code}, socket) do
    # This will be handled by JavaScript on the client side
    {:noreply, put_flash(socket, :info, "Confirmation code copied to clipboard!")}
  end

  @impl true
  def handle_event("toggle_upcoming_events", _params, socket) do
    {:noreply,
     assign(socket, :show_upcoming_events, !(socket.assigns[:show_upcoming_events] || false))}
  end

  @impl true
  def handle_event("open_rsvp", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)
    rsvp_info = Events.get_event_with_rsvp_info(uid, socket.assigns.current_member.id)

    selected_event = Map.put(event, :rsvp_info, rsvp_info)

    {:noreply,
     socket
     |> assign(:rsvp_modal_open, true)
     |> assign(:selected_event, selected_event)}
  end

  @impl true
  def handle_event("submit_rsvp", %{"uid" => uid, "response" => response}, socket) do
    current_member = socket.assigns.current_member

    result =
      case response do
        "yes" -> Events.create_rsvp(current_member.id, uid)
        "no" -> Events.delete_rsvp(current_member.id, uid)
      end

    case result do
      {:ok, _} ->
        # Refresh the events list with updated RSVP info
        updated_events =
          refresh_upcoming_events(socket.assigns.upcoming_week_events, current_member.id)

        flash_message =
          if response == "yes",
            do: "Successfully RSVPed to the event!",
            else: "RSVP cancelled successfully."

        {:noreply,
         socket
         |> assign(:upcoming_week_events, updated_events)
         |> assign(:rsvp_modal_open, false)
         |> assign(:selected_event, nil)
         |> put_flash(:info, flash_message)}

      {:error, changeset} ->
        error_message =
          case changeset.errors do
            [{_, {msg, _}} | _] -> msg
            _ -> "Unable to update RSVP. Please try again."
          end

        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  @impl true
  def handle_event("close_rsvp", _params, socket) do
    {:noreply,
     socket
     |> assign(:rsvp_modal_open, false)
     |> assign(:selected_event, nil)}
  end

  @impl true
  def handle_info({:member_checked_in, member_id}, socket) do
    current = socket.assigns.current_member

    if to_string(current.id) == to_string(member_id) do
      {:noreply,
       socket
       |> assign(:already_checked_in?, true)
       |> assign(:checkin_qr_svg, nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white shadow rounded-lg p-6">
        <div class="border-b border-gray-200 pb-4 mb-6">
          <h1 class="text-2xl font-bold text-gray-900">
            IEEE TAMU Registration - {@current_year}
          </h1>
          <p class="text-gray-600 mt-1">
            Your membership registration for the current academic year
          </p>
        </div>

        <%= case @status do %>
          <% :pending -> %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-clock" class="w-5 h-5 text-yellow-600 mr-2" />
                <h2 class="text-yellow-800 font-medium">Payment Pending</h2>
              </div>
              <div class="text-yellow-700 mt-2">
                <p>
                  Your registration is awaiting payment processing.
                </p>
                <br />
                <p>
                  If you have current membership with IEEE, make sure your IEEE member number is saved in the
                  <.link
                    navigate={~p"/members/info#info_ieee_membership_number"}
                    class="text-blue-500 hover:underline whitespace-nowrap"
                  >
                    info page <.icon name="hero-arrow-top-right-on-square" class="w-4 h-5" />.
                  </.link>
                  Once you've done so, reach out to an officer in the discord so they can mark your registration as paid.
                </p>
                <br />
                <p>
                  If you only want to sign up for branch membership, you can do so<.link
                    href="https://sofctamu.estore.flywire.com/institute-of-electrical-and-electronics-engineers/membership-dues"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-blue-500 hover:underline whitespace-nowrap"
                  >
                    here <.icon name="hero-arrow-top-right-on-square" class="w-4 h-5" />.</.link> (make sure to enter the confirmation code below in the order form)
                </p>
              </div>
            </div>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Registration Details</h2>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Confirmation Code
                  <div class="mt-1 relative">
                    <input
                      type="text"
                      value={@registration.confirmation_code}
                      readonly
                      class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900 font-mono text-lg"
                    />
                    <button
                      type="button"
                      phx-click="copy_confirmation_code"
                      phx-value-code={@registration.confirmation_code}
                      phx-hook=".CopyToClipboard"
                      id="copy-button-pending"
                      class="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                      title="Copy to clipboard"
                    >
                      <.icon name="hero-clipboard" class="w-4 h-4" />
                      <.icon name="hero-check" class="w-4 h-4 hidden text-green-600" />
                    </button>
                  </div>
                  <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyToClipboard">
                    export default {
                      mounted() {
                        this.el.addEventListener("click", (e) => {
                          const code = this.el.getAttribute("phx-value-code")
                          navigator.clipboard.writeText(code).then(() => {
                            // Toggle visibility of clipboard and check icons
                            const clipboardIcon = this.el.querySelector('[class*="hero-clipboard"]')
                            const checkIcon = this.el.querySelector('[class*="hero-check"]')

                            if (clipboardIcon && checkIcon) {
                              clipboardIcon.classList.add('hidden')
                              checkIcon.classList.remove('hidden')

                              setTimeout(() => {
                                clipboardIcon.classList.remove('hidden')
                                checkIcon.classList.add('hidden')
                              }, 1000)
                            }
                          }).catch(() => {
                            // Fallback for browsers that don't support clipboard API
                            const textArea = document.createElement("textarea")
                            textArea.value = code
                            document.body.appendChild(textArea)
                            textArea.select()
                            document.execCommand("copy")
                            document.body.removeChild(textArea)

                            // Still show the visual feedback even with fallback
                            const clipboardIcon = this.el.querySelector('[class*="hero-clipboard"]')
                            const checkIcon = this.el.querySelector('[class*="hero-check"]')

                            if (clipboardIcon && checkIcon) {
                              clipboardIcon.classList.add('hidden')
                              checkIcon.classList.remove('hidden')

                              setTimeout(() => {
                                clipboardIcon.classList.remove('hidden')
                                checkIcon.classList.add('hidden')
                              }, 1000)
                            }
                          })
                        })
                      }
                    }
                  </script>
                </label>
              </div>
            </div>
          <% :paid -> %>
            <%= if @already_checked_in? do %>
              <.checked_in_message event_name={@current_event} />
            <% else %>
              <%= if @checkin_qr_svg do %>
                <.checkin_qr svg={@checkin_qr_svg} event_name={@current_event} />
              <% end %>
            <% end %>

            <%= if @current_event == Settings.default_current_event() do %>
              <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
                <button
                  type="button"
                  phx-click="toggle_upcoming_events"
                  class="w-full flex items-center justify-between text-left"
                  aria-expanded={@show_upcoming_events}
                >
                  <span>
                    <h2 class="text-lg font-semibold text-gray-900">Upcoming Events</h2>
                    <span class="text-xs text-gray-500">Next 7 days</span>
                  </span>
                  <.icon
                    name={if @show_upcoming_events, do: "hero-chevron-up", else: "hero-chevron-down"}
                    class="w-5 h-5 text-gray-500"
                  />
                </button>

                <%= if @show_upcoming_events do %>
                  <div class="mt-4">
                    <%= if @upcoming_week_events == [] do %>
                      <p class="text-sm text-gray-600">No events scheduled in the next week.</p>
                    <% else %>
                      <ul class="space-y-4">
                        <li :for={event <- @upcoming_week_events} class="border-b last:border-0 pb-4">
                          <div class="flex items-start justify-between gap-4">
                            <div class="flex-1">
                              <div class="text-sm text-gray-600">
                                {format_local(event.dtstart, @time_zone, "%A, %B %d at %I:%M %p")}
                              </div>
                              <div class="text-base font-medium text-gray-900">{event.summary}</div>
                              <div :if={event.description} class="text-sm text-gray-700 mt-1">
                                {event.description}
                              </div>
                              <div class="text-sm text-gray-600 mt-1">
                                Location: {event.location || "TBD"}
                              </div>
                            </div>
                            <div class="shrink-0 mt-1">
                              <%= cond do %>
                                <% event.rsvp_info.at_capacity and not event.rsvp_info.member_rsvped -> %>
                                  <div class="bg-gray-100 text-gray-600 px-3 py-2 text-sm rounded-md">
                                    Event Full
                                  </div>
                                <% event.rsvp_info.member_rsvped -> %>
                                  <.button
                                    type="button"
                                    phx-click="open_rsvp"
                                    phx-value-uid={event.uid}
                                    class="bg-red-600 hover:bg-red-700 text-white text-sm"
                                  >
                                    Cancel RSVP
                                  </.button>
                                <% true -> %>
                                  <.button
                                    type="button"
                                    phx-click="open_rsvp"
                                    phx-value-uid={event.uid}
                                    class="bg-indigo-600 hover:bg-indigo-700 text-white text-sm"
                                  >
                                    RSVP
                                  </.button>
                              <% end %>
                            </div>
                          </div>
                        </li>
                      </ul>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-check-circle" class="w-5 h-5 text-green-600 mr-2" />
                <h2 class="text-green-800 font-medium">Registration Complete!</h2>
              </div>
              <p class="text-green-700 mt-2">
                Your registration and payment have been processed successfully. To get the member role in the discord, link your discord account in the
                <.link
                  navigate={~p"/members/settings"}
                  class="text-blue-500 hover:underline whitespace-nowrap"
                >
                  settings page <.icon name="hero-arrow-top-right-on-square" class="w-4 h-5" />.
                </.link>
              </p>
            </div>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Payment Details</h2>

              <%= if @registration.payment do %>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Amount Paid</label>
                    <input
                      type="text"
                      value={"$#{Decimal.to_string(@registration.payment.amount)}"}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">
                      Flywire Order ID
                    </label>
                    <input
                      type="text"
                      value={@registration.payment.id}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">T-Shirt Size</label>
                    <input
                      type="text"
                      value={@registration.payment.tshirt_size}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">Member Name</label>
                    <input
                      type="text"
                      value={@registration.payment.name}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>
                </div>
              <% else %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <.icon name="hero-information-circle" class="w-5 h-5 text-blue-600 mr-2" />
                    <h2 class="text-blue-800 font-medium">Payment Override Applied</h2>
                  </div>
                  <p class="text-blue-700 mt-2">
                    Your registration has been marked as paid by an officer.
                  </p>
                </div>
              <% end %>
            </div>
        <% end %>
      </div>
    </div>

    <!-- RSVP Modal -->
    <div
      :if={@rsvp_modal_open and @selected_event}
      id="rsvp-modal"
      class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
      phx-click="close_rsvp"
    >
      <div class="relative top-20 mx-auto p-5 border w-11/12 max-w-md shadow-lg rounded-md bg-white">
        <div class="mt-3 text-center">
          <h3 class="text-lg font-medium text-gray-900" id="modal-title">
            RSVP to Event
          </h3>
          <div class="mt-4 text-left">
            <h4 class="font-semibold text-gray-900">{@selected_event.summary}</h4>
            <p class="text-sm text-gray-600 mt-1">
              {format_local(@selected_event.dtstart, @time_zone, "%A, %B %d at %I:%M %p")}
            </p>
            <p :if={@selected_event.location} class="text-sm text-gray-600">
              Location: {@selected_event.location}
            </p>
          </div>

          <div class="mt-6">
            <%= if @selected_event.rsvp_info.member_rsvped do %>
              <p class="text-sm text-gray-600 mb-4">You are currently RSVPed to this event.</p>
              <div class="flex justify-center gap-3">
                <.button
                  type="button"
                  phx-click="submit_rsvp"
                  phx-value-uid={@selected_event.uid}
                  phx-value-response="no"
                  class="bg-red-600 hover:bg-red-700 text-white"
                >
                  Cancel RSVP
                </.button>
                <.button
                  type="button"
                  phx-click="close_rsvp"
                  class="bg-gray-300 hover:bg-gray-400 text-gray-700"
                >
                  Keep RSVP
                </.button>
              </div>
            <% else %>
              <%= if @selected_event.rsvp_info.at_capacity do %>
                <p class="text-sm text-red-600 mb-4">This event is at capacity.</p>
                <.button
                  type="button"
                  phx-click="close_rsvp"
                  class="bg-gray-300 hover:bg-gray-400 text-gray-700"
                >
                  Close
                </.button>
              <% else %>
                <p class="text-sm text-gray-600 mb-4">Would you like to RSVP to this event?</p>
                <div class="flex justify-center gap-3">
                  <.button
                    type="button"
                    phx-click="submit_rsvp"
                    phx-value-uid={@selected_event.uid}
                    phx-value-response="yes"
                    class="bg-indigo-600 hover:bg-indigo-700 text-white"
                  >
                    Yes, RSVP
                  </.button>
                  <.button
                    type="button"
                    phx-click="close_rsvp"
                    class="bg-gray-300 hover:bg-gray-400 text-gray-700"
                  >
                    Cancel
                  </.button>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Small function component to render the QR code block
  def checkin_qr(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded-lg p-6 mb-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">Event Check-in QR</h2>
      <p class="text-gray-600 mb-4">
        Show this QR to an officer to be checked in for {@event_name}.
      </p>
      <div class="flex justify-center">
        <div
          id="checkin-qrcode"
          phx-update="ignore"
          aria-label="Check-in QR Code"
          class="p-2 bg-white w-full max-w-xs sm:max-w-sm md:max-w-md"
        >
          {Phoenix.HTML.raw(@svg)}
        </div>
      </div>
    </div>
    """
  end

  # Small function component to render the checked-in message
  def checked_in_message(assigns) do
    ~H"""
    <div class="bg-white border rounded-lg p-6 mb-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-2">You're checked in</h2>
      <p>You are checked into {@event_name}.</p>
    </div>
    """
  end

  defp format_local(%DateTime{} = dt, tz, pattern) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, local} -> Calendar.strftime(local, pattern)
      _ -> Calendar.strftime(dt, pattern)
    end
  end

  defp refresh_upcoming_events(events, member_id) do
    Enum.map(events, fn event ->
      rsvp_info = Events.get_event_with_rsvp_info(event.uid, member_id)
      Map.put(event, :rsvp_info, rsvp_info)
    end)
  end
end
