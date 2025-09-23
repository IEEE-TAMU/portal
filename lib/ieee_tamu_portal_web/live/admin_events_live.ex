defmodule IeeeTamuPortalWeb.AdminEventsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.Events
  alias IeeeTamuPortal.Events.Event
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    events = Events.list_events()
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
       events: events,
       create_form: to_form(create_changeset),
       create_local_params: %{},
       show_create_form: false,
       edit_event: nil,
       edit_form: nil,
       edit_local_params: %{},
       show_edit_form: false,
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
        events = Events.list_events()
        create_changeset = Events.change_event(%Event{})

        {:noreply,
         socket
         |> assign(:events, events)
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
    edit_form = Events.change_event(event) |> to_form()

    {:noreply,
     assign(socket,
       edit_event: event,
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

    case Events.update_event(socket.assigns.edit_event, utc_params) do
      {:ok, _updated_event} ->
        events = Events.list_events()

        {:noreply,
         socket
         |> assign(:events, events)
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
        events = Events.list_events()

        {:noreply,
         socket
         |> assign(:events, events)
         |> put_flash(:info, "Event deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete event")}
    end
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
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-4 mb-2">
                    <h3 class="text-lg font-medium text-gray-900">{event.summary}</h3>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      Event
                    </span>
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
                  </div>

                  <div :if={event.description} class="text-sm text-gray-700 mb-3">
                    <p>{event.description}</p>
                  </div>

                  <div class="text-xs text-gray-500">
                    ID: {event.uid}
                  </div>
                </div>

                <div class="flex items-center space-x-2 ml-4">
                  <.button
                    type="button"
                    phx-click="edit_event"
                    phx-value-uid={event.uid}
                    class="bg-blue-600 hover:bg-blue-700 text-sm px-3 py-1"
                  >
                    <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> Edit
                  </.button>

                  <.button
                    type="button"
                    phx-click="delete_event"
                    phx-value-uid={event.uid}
                    data-confirm="Are you sure you want to delete this event?"
                    class="bg-red-600 hover:bg-red-700 text-sm px-3 py-1"
                  >
                    <.icon name="hero-trash" class="w-4 h-4 mr-1" /> Delete
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
end
