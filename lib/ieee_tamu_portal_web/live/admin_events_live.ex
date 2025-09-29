defmodule IeeeTamuPortalWeb.AdminEventsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Events.Event
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    events_with_rsvps = events_with_rsvp_counts()
    create_changeset = Events.change_event(%Event{})
    default_tz = Application.fetch_env!(:ieee_tamu_portal, :frontend_time_zone)

    time_zone =
      if connected?(socket) do
        get_connect_params(socket)["timeZone"] || default_tz
      else
        default_tz
      end

    {:ok,
     assign(socket,
       events: events_with_rsvps,
       create_form: to_form(create_changeset),
       create_local_params: %{},
       show_create_form: false,
       edit_event: nil,
       edit_form: nil,
       edit_local_params: %{},
       show_edit_form: false,
       show_rsvp_list: false,
       show_checkin_list: false,
       selected_event: nil,
       show_rsvp_qr: false,
       event_rsvps: [],
       event_checkins: [],
       page_title: "Manage Events",
       time_zone: time_zone
     )}
  end

  @impl true
  def handle_event("show_create_form", _params, socket) do
    {:noreply, assign(socket, show_create_form: true)}
  end

  @impl true
  def handle_event("hide_create_form", _params, socket) do
    create_changeset = Events.change_event(%Event{})

    {:noreply,
     assign(socket,
       show_create_form: false,
       create_form: to_form(create_changeset),
       create_local_params: %{}
     )}
  end

  @impl true
  def handle_event("validate_create", %{"event" => event_params}, socket) do
    tz = socket.assigns.time_zone
    utc_params = convert_datetime_params(event_params, tz)

    create_form =
      %Event{}
      |> Events.change_event(utc_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, create_form: create_form, create_local_params: event_params)}
  end

  @impl true
  def handle_event("create_event", %{"event" => event_params}, socket) do
    tz = socket.assigns.time_zone
    utc_params = convert_datetime_params(event_params, tz)

    case Events.create_event(utc_params) do
      {:ok, _new_event} ->
        events_with_rsvps = events_with_rsvp_counts()
        create_changeset = Events.change_event(%Event{})

        {:noreply,
         socket
         |> assign(:events, events_with_rsvps)
         |> assign(:create_form, to_form(create_changeset))
         |> assign(:create_local_params, %{})
         |> assign(:show_create_form, false)
         |> put_flash(:info, "Event created successfully")}

      {:error, changeset} ->
        {:noreply,
         assign(socket, create_form: to_form(changeset), create_local_params: event_params)}
    end
  end

  @impl true
  def handle_event("edit_event", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)
    # Add current RSVP count to the event
    rsvp_count = Events.count_rsvps(event.uid)
    event_with_rsvp = Map.put(event, :rsvp_count, rsvp_count)

    edit_form = Events.change_event(event) |> to_form()

    {:noreply,
     assign(socket,
       edit_event: event_with_rsvp,
       edit_form: edit_form,
       edit_local_params: %{},
       show_edit_form: true
     )}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     assign(socket,
       edit_event: nil,
       edit_form: nil,
       edit_local_params: %{},
       show_edit_form: false
     )}
  end

  @impl true
  def handle_event("validate_edit", %{"event" => event_params}, socket) do
    tz = socket.assigns.time_zone
    utc_params = convert_datetime_params(event_params, tz)

    # Validate RSVP limit against current count
    utc_params = validate_rsvp_limit(utc_params, socket.assigns.edit_event)

    edit_form =
      socket.assigns.edit_event
      |> Events.change_event(utc_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, edit_form: edit_form, edit_local_params: event_params)}
  end

  @impl true
  def handle_event("update_event", %{"event" => event_params}, socket) do
    tz = socket.assigns.time_zone
    utc_params = convert_datetime_params(event_params, tz)

    # Validate RSVP limit against current count
    utc_params = validate_rsvp_limit(utc_params, socket.assigns.edit_event)

    case Events.update_event(socket.assigns.edit_event, utc_params) do
      {:ok, _updated_event} ->
        events_with_rsvps = events_with_rsvp_counts()

        {:noreply,
         socket
         |> assign(:events, events_with_rsvps)
         |> assign(:edit_event, nil)
         |> assign(:edit_form, nil)
         |> assign(:edit_local_params, %{})
         |> assign(:show_edit_form, false)
         |> put_flash(:info, "Event updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset), edit_local_params: event_params)}
    end
  end

  @impl true
  def handle_event("delete_event", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)

    case Events.delete_event(event) do
      {:ok, _} ->
        events_with_rsvps = events_with_rsvp_counts()

        {:noreply,
         socket
         |> assign(:events, events_with_rsvps)
         |> put_flash(:info, "Event deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete event")}
    end
  end

  @impl true
  def handle_event("show_event_rsvps", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)
    rsvps = Events.list_event_rsvps(uid)

    {:noreply,
     assign(socket,
       show_rsvp_list: true,
       selected_event: event,
       event_rsvps: rsvps,
       show_checkin_list: false
     )}
  end

  @impl true
  def handle_event("show_event_checkins", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)
    checkins = Events.list_event_checkins(event.summary)

    {:noreply,
     assign(socket,
       show_checkin_list: true,
       selected_event: event,
       event_checkins: checkins,
       show_rsvp_list: false
     )}
  end

  @impl true
  def handle_event("close_lists", _params, socket) do
    {:noreply,
     assign(socket,
       show_rsvp_list: false,
       show_checkin_list: false,
       selected_event: nil,
       event_rsvps: [],
       event_checkins: []
     )}
  end

  @impl true
  def handle_event("show_rsvp_qr", %{"uid" => uid}, socket) do
    event = Events.get_event!(uid)

    # Generate QR code URL for RSVP
    rsvp_url = url(~p"/members/registration?rsvp=#{uid}")
    rsvp_qr_svg = EQRCode.encode(rsvp_url) |> EQRCode.svg()

    {:noreply,
     assign(socket,
       show_rsvp_qr: true,
       rsvp_qr_event: event,
       rsvp_qr_svg: rsvp_qr_svg
     )}
  end

  @impl true
  def handle_event("close_rsvp_qr", _params, socket) do
    {:noreply,
     assign(socket,
       show_rsvp_qr: false,
       rsvp_qr_event: nil,
       rsvp_qr_svg: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Events Management</h1>
            <p class="text-gray-600 mt-2">Create and manage events</p>
          </div>
          <.link
            navigate={~p"/admin"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Dashboard
          </.link>
        </div>
      </div>
      
    <!-- Create Event Form -->
      <div class="flex justify-end mb-6">
        <.button phx-click="show_create_form" class="bg-blue-600 hover:bg-blue-700">
          <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Create New Event
        </.button>
      </div>
      
    <!-- Create Event Modal -->
      <div :if={@show_create_form}>
        <.modal
          id="create-event-modal"
          on_cancel={JS.push("hide_create_form")}
          show={@show_create_form}
        >
          <div class="p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Create New Event</h2>
            <.simple_form
              for={@create_form}
              phx-change="validate_create"
              phx-submit="create_event"
              class="space-y-6"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <.input field={@create_form[:summary]} type="text" label="Event Title" required />
                <.input field={@create_form[:organizer]} type="text" label="Organizer" />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <.input
                  field={@create_form[:dtstart]}
                  type="datetime-local"
                  label="Start Date & Time"
                  value={@create_local_params["dtstart"]}
                  required
                />
                <.input
                  field={@create_form[:dtend]}
                  type="datetime-local"
                  label="End Date & Time"
                  value={@create_local_params["dtend"]}
                />
              </div>

              <.input field={@create_form[:location]} type="text" label="Location" />
              <.input field={@create_form[:description]} type="textarea" label="Description" rows="4" />
              <.input
                field={@create_form[:rsvp_limit]}
                type="number"
                label="RSVP Limit (optional)"
                placeholder="Leave blank for unlimited"
              />

              <div class="flex justify-end space-x-3">
                <.button
                  type="button"
                  phx-click="hide_create_form"
                  class="bg-gray-200 text-gray-800 hover:bg-gray-300"
                >
                  Cancel
                </.button>
                <.button type="submit" class="bg-blue-600 hover:bg-blue-700">
                  Create Event
                </.button>
              </div>
            </.simple_form>
          </div>
        </.modal>
      </div>
      
    <!-- Edit Event Modal -->
      <div :if={@show_edit_form}>
        <.modal id="edit-event-modal" on_cancel={JS.push("cancel_edit")} show={@show_edit_form}>
          <div class="p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Edit Event</h2>
            <.simple_form
              for={@edit_form}
              phx-change="validate_edit"
              phx-submit="update_event"
              class="space-y-4"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input field={@edit_form[:summary]} type="text" label="Event Title" />
                <.input field={@edit_form[:organizer]} type="text" label="Organizer" />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@edit_form[:dtstart]}
                  type="datetime-local"
                  label="Start Date & Time"
                  value={
                    @edit_local_params["dtstart"] ||
                      to_local_naive_input(@edit_event && @edit_event.dtstart, @time_zone)
                  }
                />
                <.input
                  field={@edit_form[:dtend]}
                  type="datetime-local"
                  label="End Date & Time"
                  value={
                    @edit_local_params["dtend"] ||
                      to_local_naive_input(@edit_event && @edit_event.dtend, @time_zone)
                  }
                />
              </div>

              <.input field={@edit_form[:location]} type="text" label="Location" />
              <.input field={@edit_form[:description]} type="textarea" label="Description" rows="3" />

              <div>
                <.input
                  field={@edit_form[:rsvp_limit]}
                  type="number"
                  label="RSVP Limit (optional)"
                  placeholder="Leave blank for unlimited"
                />
                <%= if @edit_event.rsvp_count > 0 do %>
                  <p class="mt-1 text-sm text-gray-600">
                    Current RSVPs: <strong>{@edit_event.rsvp_count}</strong>
                    <%= if @edit_event.rsvp_limit do %>
                      (limit cannot be set below this number)
                    <% end %>
                  </p>
                <% end %>
              </div>

              <div class="flex justify-end space-x-3">
                <.button
                  type="button"
                  phx-click="cancel_edit"
                  class="bg-gray-200 text-gray-800 hover:bg-gray-300"
                >
                  Cancel
                </.button>
                <.button type="submit" class="bg-green-600 hover:bg-green-700">
                  Update Event
                </.button>
              </div>
            </.simple_form>
          </div>
        </.modal>
      </div>
      
    <!-- RSVPs List Modal -->
      <div :if={@show_rsvp_list}>
        <.modal id="rsvps-modal" on_cancel={JS.push("close_lists")} show={@show_rsvp_list}>
          <div class="p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">
              RSVPs for "{@selected_event.summary}"
            </h2>
            <div :if={@event_rsvps == []} class="text-center text-gray-500 py-8">
              No RSVPs found for this event.
            </div>
            <div :if={@event_rsvps != []} class="space-y-3 max-h-96 overflow-y-auto">
              <div
                :for={rsvp <- @event_rsvps}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <div>
                  <div class="font-medium text-gray-900">
                    <%= if rsvp.preferred_name && rsvp.preferred_name != "" do %>
                      {rsvp.preferred_name} ({rsvp.first_name} {rsvp.last_name})
                    <% else %>
                      {rsvp.first_name} {rsvp.last_name}
                    <% end %>
                  </div>
                  <div class="text-sm text-gray-600">{rsvp.email}</div>
                </div>
                <div class="text-sm text-gray-500">
                  {format_local(rsvp.inserted_at, @time_zone, "%B %d, %Y at %I:%M %p")}
                </div>
              </div>
            </div>
            <div class="flex justify-between items-center mt-6">
              <div class="text-sm text-gray-600 whitespace-nowrap">
                <span class="invisible md:visible">Total</span>
                RSVPs: <strong>{length(@event_rsvps)}</strong>
              </div>
              <div class="flex space-x-3">
                <.link
                  :if={length(@event_rsvps) > 0}
                  href={~p"/admin/download-event-rsvps/#{@selected_event.uid}"}
                  target="_blank"
                  class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download
                </.link>
                <.button
                  type="button"
                  phx-click="close_lists"
                  class="bg-gray-200 text-gray-800 hover:bg-gray-300"
                >
                  Close
                </.button>
              </div>
            </div>
          </div>
        </.modal>
      </div>
      
    <!-- Checkins List Modal -->
      <div :if={@show_checkin_list}>
        <.modal id="checkins-modal" on_cancel={JS.push("close_lists")} show={@show_checkin_list}>
          <div class="p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">
              Checkins for "{@selected_event.summary}"
            </h2>
            <div :if={@event_checkins == []} class="text-center text-gray-500 py-8">
              No checkins found for this event.
            </div>
            <div :if={@event_checkins != []} class="space-y-3 max-h-96 overflow-y-auto">
              <div
                :for={checkin <- @event_checkins}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <div>
                  <div class="font-medium text-gray-900">
                    <%= if checkin.preferred_name && checkin.preferred_name != "" do %>
                      {checkin.preferred_name} ({checkin.first_name} {checkin.last_name})
                    <% else %>
                      {checkin.first_name} {checkin.last_name}
                    <% end %>
                  </div>
                  <div class="text-sm text-gray-600">{checkin.email}</div>
                </div>
                <div class="text-sm text-gray-500">
                  {format_local(checkin.inserted_at, @time_zone, "%B %d, %Y at %I:%M %p")}
                </div>
              </div>
            </div>
            <div class="flex justify-between items-center mt-6">
              <div class="text-sm text-gray-600">
                <span class="invisible md:visible">Total</span>Checkins:
                <strong>{length(@event_checkins)}</strong>
              </div>
              <div class="flex space-x-3">
                <.link
                  :if={length(@event_checkins) > 0}
                  href={~p"/admin/download-event-checkins/#{@selected_event.uid}"}
                  target="_blank"
                  class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-2" /> Download CSV
                </.link>
                <.button
                  type="button"
                  phx-click="close_lists"
                  class="bg-gray-200 text-gray-800 hover:bg-gray-300"
                >
                  Close
                </.button>
              </div>
            </div>
          </div>
        </.modal>
      </div>
      
    <!-- RSVP QR Code Modal -->
      <div :if={@show_rsvp_qr}>
        <.modal id="rsvp-qr-modal" on_cancel={JS.push("close_rsvp_qr")} show={@show_rsvp_qr}>
          <div class="p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">
              RSVP QR Code for "{@rsvp_qr_event.summary}"
            </h2>
            <p class="text-gray-600 mb-4">
              Members can scan this QR code to quickly RSVP to the event.
            </p>
            <div class="flex justify-center mb-6">
              <div
                id="rsvp-qrcode"
                phx-update="ignore"
                aria-label="RSVP QR Code"
                class="p-2 sm:p-4 bg-white border border-gray-200 rounded-lg w-full max-w-[250px] sm:max-w-xs [&>svg]:w-full [&>svg]:h-auto [&>svg]:max-w-full"
              >
                {Phoenix.HTML.raw(@rsvp_qr_svg)}
              </div>
            </div>
            <div class="bg-gray-50 rounded-md p-3 mb-4">
              <p class="text-sm text-gray-600">
                <strong>QR Code URL:</strong>
                <br />
                <code class="text-xs break-all">
                  {url(~p"/members/registration?rsvp=#{@rsvp_qr_event.uid}")}
                </code>
              </p>
            </div>
            <div class="flex justify-end">
              <.button
                type="button"
                phx-click="close_rsvp_qr"
                class="bg-gray-200 text-gray-800 hover:bg-gray-300"
              >
                Close
              </.button>
            </div>
          </div>
        </.modal>
      </div>
      
    <!-- Events List -->
      <div class="bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-medium text-gray-900">
            Existing Events ({length(@events)})
          </h2>
        </div>

        <div :if={@events == []} class="p-6 text-center text-gray-500">
          No events found. Create your first event above.
        </div>

        <div :if={@events != []} class="divide-y divide-gray-200">
          <div :for={event <- @events} class="p-6">
            <div>
              <!-- Display Event -->
              <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4">
                <div class="flex-1">
                  <div class="flex items-center gap-4 mb-2">
                    <h3 class="text-lg font-medium text-gray-900">{event.summary}</h3>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      Event
                    </span>
                    <%= if event.rsvp_limit && event.rsvp_count >= event.rsvp_limit do %>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                        At Capacity
                      </span>
                    <% end %>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-gray-600 mb-3">
                    <div class="flex items-center">
                      <.icon name="hero-calendar" class="w-4 h-4 mr-2" />
                      <span>
                        <%= if event.dtstart do %>
                          {format_local(event.dtstart, @time_zone, "%B %d, %Y at %I:%M %p")}
                        <% end %>
                        <%= if event.dtend do %>
                          - {format_local(event.dtend, @time_zone, "%I:%M %p")}
                        <% end %>
                      </span>
                    </div>

                    <div :if={event.location} class="flex items-center">
                      <.icon name="hero-map-pin" class="w-4 h-4 mr-2" />
                      <span>{event.location}</span>
                    </div>

                    <div :if={event.organizer} class="flex items-center">
                      <.icon name="hero-user" class="w-4 h-4 mr-2" />
                      <span>{event.organizer}</span>
                    </div>

                    <div :if={event.rsvp_limit} class="flex items-center">
                      <.icon name="hero-users" class="w-4 h-4 mr-2" />
                      <span>RSVPs: {event.rsvp_count}/{event.rsvp_limit}</span>
                    </div>

                    <div :if={!event.rsvp_limit && event.rsvp_count > 0} class="flex items-center">
                      <.icon name="hero-users" class="w-4 h-4 mr-2" />
                      <span>RSVPs: {event.rsvp_count} (unlimited)</span>
                    </div>
                  </div>

                  <div :if={event.description} class="text-sm text-gray-700 mb-3">
                    <p>{event.description}</p>
                  </div>
                </div>

                <div class="flex flex-wrap items-center gap-2 lg:space-x-2 lg:ml-4">
                  <.button
                    type="button"
                    phx-click="show_event_rsvps"
                    phx-value-uid={event.uid}
                    class="bg-green-600 hover:bg-green-700 text-xs sm:text-sm px-2 sm:px-3 py-1"
                  >
                    <.icon name="hero-users" class="w-3 h-3 sm:w-4 sm:h-4" />
                    <span class="hidden sm:inline">RSVPs </span>({event.rsvp_count})
                  </.button>

                  <.button
                    type="button"
                    phx-click="show_event_checkins"
                    phx-value-uid={event.uid}
                    class="bg-purple-600 hover:bg-purple-700 text-xs sm:text-sm px-2 sm:px-3 py-1"
                  >
                    <.icon name="hero-check-circle" class="w-3 h-3 sm:w-4 sm:h-4" />
                    <span class="hidden sm:inline">Checkins </span>({event.checkin_count})
                  </.button>

                  <.button
                    type="button"
                    phx-click="show_rsvp_qr"
                    phx-value-uid={event.uid}
                    class="bg-indigo-600 hover:bg-indigo-700 text-xs sm:text-sm px-2 sm:px-3 py-1"
                  >
                    <.icon name="hero-qr-code" class="w-3 h-3 sm:w-4 sm:h-4" />
                    <span class="hidden sm:inline">RSVP </span>QR
                  </.button>

                  <.button
                    type="button"
                    phx-click="edit_event"
                    phx-value-uid={event.uid}
                    class="bg-blue-600 hover:bg-blue-700 text-xs sm:text-sm px-2 sm:px-3 py-1"
                  >
                    <.icon name="hero-pencil" class="w-3 h-3 sm:w-4 sm:h-4" />
                    <span class="hidden sm:inline">Edit</span>
                  </.button>

                  <.button
                    type="button"
                    phx-click="delete_event"
                    phx-value-uid={event.uid}
                    data-confirm="Are you sure you want to delete this event?"
                    class="bg-red-600 hover:bg-red-700 text-xs sm:text-sm px-2 sm:px-3 py-1"
                  >
                    <.icon name="hero-trash" class="w-3 h-3 sm:w-4 sm:h-4" />
                    <span class="hidden sm:inline">Delete</span>
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Timezone helpers --
  defp convert_datetime_params(params, tz) do
    params
    |> convert_one("dtstart", tz)
    |> convert_one("dtend", tz)
  end

  defp convert_one(params, key, tz) do
    case Map.get(params, key) do
      nil ->
        params

      "" ->
        params

      value when is_binary(value) ->
        case parse_local_to_utc(value, tz) do
          {:ok, dt_utc} -> Map.put(params, key, dt_utc)
          {:error, _} -> params
        end
    end
  end

  defp parse_local_to_utc(str, tz) do
    naive_result =
      case NaiveDateTime.from_iso8601(str) do
        {:ok, naive} -> {:ok, naive}
        _ -> NaiveDateTime.from_iso8601(str <> ":00")
      end

    with {:ok, naive} <- naive_result,
         {:ok, local} <- DateTime.from_naive(naive, tz) do
      DateTime.shift_zone(local, "Etc/UTC")
    else
      {:ambiguous, first, _second} -> DateTime.shift_zone(first, "Etc/UTC")
      {:gap, _naive, _} -> {:error, :time_gap}
      other -> other
    end
  end

  defp to_local_naive_input(nil, _tz), do: nil

  defp to_local_naive_input(%DateTime{} = dt, tz) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, local} ->
        local
        |> DateTime.to_naive()
        |> naive_to_input_string()

      _ ->
        nil
    end
  end

  defp naive_to_input_string(%NaiveDateTime{} = naive) do
    # HTML datetime-local expects YYYY-MM-DDTHH:MM
    NaiveDateTime.to_iso8601(naive)
    |> String.slice(0, 16)
  end

  defp format_local(%DateTime{} = dt, tz, pattern) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, local} -> Calendar.strftime(local, pattern)
      _ -> Calendar.strftime(dt, pattern)
    end
  end

  # Validates that RSVP limit is not set below current RSVP count
  defp validate_rsvp_limit(params, event) do
    case {Map.get(params, "rsvp_limit"), event.rsvp_count} do
      {nil, _} ->
        params

      {"", _} ->
        params

      {limit_str, current_count} when is_binary(limit_str) ->
        case Integer.parse(limit_str) do
          {limit, ""} when limit < current_count ->
            # Set a custom error - we'll handle this in the changeset
            Map.put(
              params,
              "rsvp_limit_error",
              "Cannot set limit below current RSVP count (#{current_count})"
            )

          _ ->
            params
        end

      _ ->
        params
    end
  end

  # Helper to get events with RSVP counts
  defp events_with_rsvp_counts do
    Events.list_events()
    |> Enum.map(fn event ->
      rsvp_count = Events.count_rsvps(event.uid)
      checkin_count = Events.count_event_checkins(event.summary)

      event
      |> Map.put(:rsvp_count, rsvp_count)
      |> Map.put(:checkin_count, checkin_count)
    end)
  end
end
