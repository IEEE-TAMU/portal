defmodule IeeeTamuPortalWeb.TestTableLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Accounts, Members, Settings}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Members - Admin")
      |> assign(:show_resume_modal, false)
      |> assign(:current_resume_url, nil)
      |> assign(:current_member_email, nil)
      |> assign(:current_resume_member_id, nil)
      |> assign(:show_member_modal, false)
      |> assign(:current_member, nil)
      |> assign(:member_info_form, nil)
      |> assign(:view_only_mode, false)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    dbg(params)
    {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(params)
    {:noreply, assign(socket, members: members, meta: meta)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    # Handle both meta params and filter params from Flop
    query_params =
      case params do
        %{"meta" => meta_params} -> meta_params
        other_params -> other_params
      end

    {:noreply, push_patch(socket, to: ~p"/admin/test_table?#{query_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/test_table")}
  end

  @impl true
  def handle_event("mark_as_paid", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))
    current_year = Settings.get_registration_year!()

    case Members.toggle_payment_override(member, current_year) do
      {:ok, _updated_registration} ->
        # Refresh the members list to get updated data
        {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(socket.assigns.meta.params)

        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:info, "Payment marked as paid for #{member.email}")
         |> assign(:members, members)
         |> assign(:meta, meta)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Failed to update payment status for #{member.email}"
         )}
    end
  end

  @impl true
  def handle_event("toggle_payment_override", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))
    current_year = Settings.get_registration_year!()

    case Members.toggle_payment_override(member, current_year) do
      {:ok, updated_registration} ->
        # Refresh the members list to get updated data
        {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(socket.assigns.meta.params)

        action = if updated_registration.payment_override, do: "enabled", else: "disabled"

        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:info, "Payment override #{action} for #{member.email}")
         |> assign(:members, members)
         |> assign(:meta, meta)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Failed to toggle payment override for #{member.email}"
         )}
    end
  end

  @impl true
  def handle_event("mark_as_paid", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case mark_member_as_paid(member) do
      {:ok, updated_member} ->
        # Update the member in the members list
        updated_members =
          Enum.map(socket.assigns.members, fn m ->
            if m.id == member_id do
              updated_member
            else
              m
            end
          end)

        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "Payment marked as paid for #{member.email}")
          |> assign(:members, updated_members)

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Failed to update payment status for #{member.email}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_payment_override", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case mark_member_as_paid(member) do
      {:ok, updated_member} ->
        # Update the member in the members list
        updated_members =
          Enum.map(socket.assigns.members, fn m ->
            if m.id == member_id do
              updated_member
            else
              m
            end
          end)

        # Determine the action for the flash message
        action =
          case get_payment_status(updated_member) do
            :override -> "enabled"
            :unpaid -> "disabled"
            :paid -> "disabled"
          end

        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "Payment override #{action} for #{member.email}")
          |> assign(:members, updated_members)

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Failed to toggle payment override for #{member.email}"
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_member", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)

    # Use Members context to load member with info
    case Members.get_member_with_preloads(member_id, [:info]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        # Create info form
        info_form = Members.change_member_info(member.info) |> to_form()

        {:noreply,
         socket
         |> assign(:show_member_modal, true)
         |> assign(:current_member, member)
         |> assign(:member_info_form, info_form)
         |> assign(:view_only_mode, false)}
    end
  end

  @impl true
  def handle_event("view_member", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)

    # Use Members context to load member with info
    case Members.get_member_with_preloads(member_id, [:info]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        # Create info form
        info_form = Members.change_member_info(member.info) |> to_form()

        {:noreply,
         socket
         |> assign(:show_member_modal, true)
         |> assign(:current_member, member)
         |> assign(:member_info_form, info_form)
         |> assign(:view_only_mode, true)}
    end
  end

  @impl true
  def handle_event("close_member_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_member_modal, false)
     |> assign(:current_member, nil)
     |> assign(:member_info_form, nil)
     |> assign(:view_only_mode, false)}
  end

  @impl true
  def handle_event("validate_member_info", params, socket) do
    %{"info" => info_params} = params
    member = socket.assigns.current_member

    info_form =
      member.info
      |> Members.change_member_info(info_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, member_info_form: info_form)}
  end

  @impl true
  def handle_event("update_member_info", params, socket) do
    %{"info" => info_params} = params
    member = socket.assigns.current_member

    update_or_create_info = fn
      %Members.Info{} = info -> Members.update_member_info(info, info_params)
      nil -> Members.create_member_info(member, info_params)
    end

    case update_or_create_info.(member.info) do
      {:ok, info} ->
        updated_member = %Accounts.Member{member | info: info}

        # Refresh the members list to keep Flop pagination intact
        {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(socket.assigns.meta.params)

        info_form = Members.change_member_info(info) |> to_form()

        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:info, "Member information updated successfully.")
         |> assign(:current_member, updated_member)
         |> assign(:member_info_form, info_form)
         |> assign(:members, members)
         |> assign(:meta, meta)}

      {:error, changeset} ->
        {:noreply, assign(socket, member_info_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("view_member", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    # Preload member info
    member = Accounts.preload_member_info(member)

    # Create info form
    info_form = Members.change_member_info(member.info) |> to_form()

    {:noreply,
     socket
     |> assign(:show_member_modal, true)
     |> assign(:current_member, member)
     |> assign(:member_info_form, info_form)
     |> assign(:view_only_mode, true)}
  end

  @impl true
  def handle_event("close_member_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_member_modal, false)
     |> assign(:current_member, nil)
     |> assign(:member_info_form, nil)
     |> assign(:view_only_mode, false)}
  end

  @impl true
  def handle_event("validate_member_info", params, socket) do
    %{"info" => info_params} = params
    member = socket.assigns.current_member

    info_form =
      member.info
      |> Members.change_member_info(info_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, member_info_form: info_form)}
  end

  @impl true
  def handle_event("update_member_info", params, socket) do
    %{"info" => info_params} = params
    member = socket.assigns.current_member

    update_or_create_info = fn
      %Members.Info{} = info -> Members.update_member_info(info, info_params)
      nil -> Members.create_member_info(member, info_params)
    end

    case update_or_create_info.(member.info) do
      {:ok, info} ->
        updated_member = %Accounts.Member{member | info: info}

        # Update the member in the members list - refresh the list to keep Flop pagination intact
        {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(socket.assigns.meta.params)

        info_form = Members.change_member_info(info) |> to_form()

        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "Member information updated successfully.")
          |> assign(:current_member, updated_member)
          |> assign(:member_info_form, info_form)
          |> assign(:members, members)
          |> assign(:meta, meta)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, member_info_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event(
        "show_resume",
        %{"email" => email, "member_id" => member_id},
        socket
      ) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case member.resume do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "No resume found for #{email}")}

      resume ->
        # Generate signed URL for the resume
        {:ok, signed_url} =
          Members.Resume.signed_url(resume,
            method: "GET",
            response_content_type: "application/pdf"
          )

        {:noreply,
         socket
         |> assign(:show_resume_modal, true)
         |> assign(:current_resume_url, signed_url)
         |> assign(:current_member_email, email)
         |> assign(:current_resume_member_id, member_id)}
    end
  end

  @impl true
  def handle_event("close_resume_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_resume_modal, false)
     |> assign(:current_resume_url, nil)
     |> assign(:current_member_email, nil)
     |> assign(:current_resume_member_id, nil)}
  end

  @impl true
  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_member_resume", _params, socket) do
    # Check if we're in resume modal or member modal context
    member_id =
      socket.assigns[:current_resume_member_id] ||
        (socket.assigns[:current_member] && socket.assigns[:current_member].id)

    # Use Members context to get member with resume and delete it
    case Members.get_member_with_preloads(member_id, [:resume]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        case Members.delete_member_resume(member) do
          {:ok, _updated_member} ->
            # Refresh the members list
            {members, meta} =
              IeeeTamuPortal.Accounts.Member.list_members(socket.assigns.meta.params)

            socket =
              socket
              |> Phoenix.LiveView.put_flash(:info, "Resume deleted successfully.")
              |> assign(:members, members)
              |> assign(:meta, meta)
              |> assign(:show_resume_modal, false)
              |> assign(:current_resume_url, nil)
              |> assign(:current_member_email, nil)
              |> assign(:current_resume_member_id, nil)

            # If we're also in member modal, update current_member
            socket =
              if socket.assigns[:current_member] && socket.assigns.current_member.id == member_id do
                updated_member = Members.get_member_with_preloads(member_id, [:info])
                assign(socket, :current_member, updated_member)
              else
                socket
              end

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete resume")}
        end
    end
  end

  @impl true
  def handle_event("resend_confirmation", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case Accounts.deliver_member_confirmation_instructions(
           member,
           &url(~p"/members/confirm/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Confirmation email sent successfully to #{member.email}")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send confirmation email to #{member.email}")}
    end
  end

  @impl true
  def handle_event("resend_confirmation", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case Accounts.deliver_member_confirmation_instructions(
           member,
           &url(~p"/members/confirm/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Confirmation email sent successfully to #{member.email}")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send confirmation email to #{member.email}")}
    end
  end

  # Helper function to mark member as paid
  defp mark_member_as_paid(member) do
    alias IeeeTamuPortal.{Members, Settings}

    current_year = Settings.get_registration_year!()

    case Members.toggle_payment_override(member, current_year) do
      {:ok, updated_registration} ->
        # Update the member with the new registration data
        updated_registrations =
          case member.registrations do
            [] -> [updated_registration]
            [_old_reg] -> [updated_registration]
            # shouldn't happen with our query
            multiple -> multiple
          end

        updated_member = %{member | registrations: updated_registrations}
        {:ok, updated_member}

      error ->
        error
    end
  end

  # Helper function to get payment status from registrations
  defp get_payment_status(member) do
    case member.registrations do
      [] ->
        :unpaid

      [registration] ->
        cond do
          registration.payment_override -> :override
          # Check if payment is actually loaded and not nil
          match?(%Ecto.Association.NotLoaded{}, registration.payment) -> :unpaid
          registration.payment != nil -> :paid
          true -> :unpaid
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Members</h1>
          <p class="mt-2 text-sm text-gray-700">
            A list of all members in the IEEE TAMU Portal.
          </p>
        </div>
      </div>
      
    <!-- Filter Form -->
      <div class="mt-6 bg-white shadow rounded-lg p-4">
        <.form
          for={to_form(@meta)}
          as={:meta}
          class="space-y-4"
          phx-change="filter"
          phx-submit="filter"
        >
          <div class="flex items-end justify-between gap-3">
            <div class="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
              <Flop.Phoenix.filter_fields
                :let={i}
                form={to_form(@meta)}
                fields={[
                  email: [
                    label: "Filter by Email",
                    type: "text",
                    placeholder: "Enter email to search...",
                    op: :like
                  ],
                  full_name: [
                    label: "Filter by Name",
                    type: "text",
                    placeholder: "Enter first or last name to search...",
                    op: :like
                  ]
                ]}
              >
                <.input
                  field={i.field}
                  label={i.label}
                  type={i.type}
                  {i.rest}
                />
              </Flop.Phoenix.filter_fields>
            </div>

            <div class="flex space-x-2">
              <.button
                type="submit"
                class="bg-indigo-600 hover:bg-indigo-700"
              >
                Filter
              </.button>
              <.button
                type="button"
                phx-click="clear_filters"
                class="bg-gray-500 hover:bg-gray-600"
              >
                Clear
              </.button>
            </div>
          </div>
        </.form>
      </div>

      <div class="mt-6">
        <div class="flex items-center justify-center">
          <Flop.Phoenix.pagination
            meta={@meta}
            path={~p"/admin/test_table"}
            page_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}
            current_page_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-indigo-600 rounded-md"
            ]}
            page_list_attrs={[class: "flex space-x-1"]}
            disabled_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-white border border-gray-300 cursor-default rounded-md"
            ]}
            class="flex items-center space-x-2"
          >
            <:previous attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}>
              Previous
            </:previous>
            <:next attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}>
              Next
            </:next>
          </Flop.Phoenix.pagination>
        </div>
      </div>

      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <Flop.Phoenix.table
                items={@members}
                meta={@meta}
                path={~p"/admin/test_table"}
                id="members-table"
                opts={[
                  table_attrs: [class: "min-w-full divide-y divide-gray-300"],
                  thead_attrs: [class: "bg-gray-50"],
                  tbody_attrs: [class: "divide-y divide-gray-200 bg-white"],
                  thead_th_attrs: [
                    class: "px-3 py-3.5 text-left text-sm font-semibold text-gray-900",
                    scope: "col"
                  ],
                  tbody_td_attrs: [class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"],
                  tbody_tr_attrs: [class: "hover:bg-gray-50"],
                  no_results_content: nil
                ]}
              >
                <:col
                  :let={member}
                  label="Name/Email"
                  field={:email}
                  thead_th_attrs={[
                    class: "py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6",
                    scope: "col"
                  ]}
                  tbody_td_attrs={[
                    class:
                      "whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"
                  ]}
                >
                  <%= if member.info && member.info.first_name && member.info.last_name do %>
                    {member.info.first_name} {member.info.last_name}
                    <div class="text-xs text-gray-500">{member.email}</div>
                  <% else %>
                    {member.email}
                  <% end %>
                </:col>
                
                <:col
                  :let={member}
                  label="Status"
                  field={:confirmed_at}
                  tbody_td_attrs={[class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"]}
                >
                  <%= if member.confirmed_at do %>
                    <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                      Confirmed
                    </span>
                  <% else %>
                    <span class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
                      Unconfirmed
                    </span>
                  <% end %>
                </:col>
                <:col
                  :let={member}
                  label="Payment"
                  tbody_td_attrs={[class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500 w-32"]}
                >
                  <%= case Members.get_payment_status(member) do %>
                    <% :paid -> %>
                      <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                        Paid
                      </span>
                    <% :override -> %>
                      <button
                        phx-click="toggle_payment_override"
                        phx-value-member-id={member.id}
                        class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 hover:bg-blue-200 cursor-pointer transition-colors"
                        title="Click to remove override"
                      >
                        Override
                      </button>
                    <% :unpaid -> %>
                      <button
                        phx-click="mark_as_paid"
                        phx-value-member-id={member.id}
                        class="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800 hover:bg-red-200 cursor-pointer transition-colors"
                        title="Click to mark as paid"
                      >
                        Unpaid
                      </button>
                  <% end %>
                </:col>
                <:col
                  :let={member}
                  label="Joined"
                  field={:inserted_at}
                  tbody_td_attrs={[class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"]}
                >
                  {Calendar.strftime(member.inserted_at, "%b %d, %Y")}
                </:col>
                <:col
                  :let={member}
                  label="Resume"
                  tbody_td_attrs={[class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"]}
                >
                  <%= if member.resume do %>
                    <button
                      phx-click="show_resume"
                      phx-value-email={member.email}
                      phx-value-member_id={member.id}
                      class="inline-flex items-center rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 hover:bg-blue-200 cursor-pointer transition-colors"
                    >
                      View Resume
                    </button>
                  <% else %>
                    <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800">
                      Not Uploaded
                    </span>
                  <% end %>
                </:col>
                <:col
                  :let={member}
                  label="Actions"
                  tbody_td_attrs={[
                    class:
                      "relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6"
                  ]}
                >
                  <div class="flex justify-end space-x-2">
                    <button
                      phx-click="view_member"
                      phx-value-member_id={member.id}
                      class="text-indigo-600 hover:text-indigo-900 text-xs"
                    >
                      View
                    </button>
                    <button
                      phx-click="show_member"
                      phx-value-member_id={member.id}
                      class="text-indigo-600 hover:text-indigo-900 text-xs"
                    >
                      Edit
                    </button>
                    <%= if !member.confirmed_at do %>
                      <button
                        phx-click="resend_confirmation"
                        phx-value-member_id={member.id}
                        class="text-orange-600 hover:text-orange-900 text-xs"
                      >
                        Resend
                      </button>
                    <% end %>
                  </div>
                </:col>
              </Flop.Phoenix.table>

              <%= if Enum.empty?(@members) do %>
                <div class="text-center py-12 bg-white">
                  <.icon name="hero-users" class="mx-auto h-12 w-12 text-gray-400" />
                  <h3 class="mt-2 text-sm font-semibold text-gray-900">No members</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    No members match your search criteria.`
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <div class="flex items-center justify-center">
          <Flop.Phoenix.pagination
            meta={@meta}
            path={~p"/admin/test_table"}
            page_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}
            current_page_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-indigo-600 rounded-md"
            ]}
            page_list_attrs={[class: "flex space-x-1"]}
            disabled_link_attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-white border border-gray-300 cursor-default rounded-md"
            ]}
            class="flex items-center space-x-2"
          >
            <:previous attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}>
              Previous
            </:previous>
            <:next attrs={[
              class:
                "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            ]}>
              Next
            </:next>
          </Flop.Phoenix.pagination>
        </div>
      </div>

      <%= if @show_resume_modal do %>
        <div
          class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
          phx-click="close_resume_modal"
          phx-window-keydown="close_resume_modal"
          phx-key="Escape"
        >
          <div
            class="relative top-20 mx-auto p-5 border w-11/12 max-w-6xl shadow-lg rounded-md bg-white"
            phx-click="prevent_close"
          >
            <div class="mt-3">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">
                  Resume - {@current_member_email}
                </h3>
                <button
                  phx-click="close_resume_modal"
                  class="text-gray-400 hover:text-gray-600 focus:outline-none"
                >
                  <.icon name="hero-x-mark" class="h-6 w-6" />
                </button>
              </div>

              <div class="w-full" style="height: 70vh;">
                <embed
                  src={@current_resume_url}
                  type="application/pdf"
                  class="w-full h-full border rounded"
                />
              </div>

              <div class="flex justify-between items-center mt-4">
                <.button
                  type="button"
                  phx-click="delete_member_resume"
                  phx-disable-with="Deleting..."
                  class="bg-red-600 hover:bg-red-700 text-white"
                  onclick="return confirm('Are you sure you want to delete this member\\'s resume?')"
                >
                  Delete Resume
                </.button>
                <button
                  phx-click="close_resume_modal"
                  class="px-4 py-2 bg-gray-300 hover:bg-gray-400 rounded text-gray-800 font-medium"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_member_modal && @current_member do %>
        <div
          class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
          phx-click="close_member_modal"
          phx-window-keydown="close_member_modal"
          phx-key="Escape"
        >
          <div
            class="relative top-10 mx-auto p-6 border w-11/12 max-w-4xl shadow-lg rounded-md bg-white max-h-screen overflow-y-auto"
            phx-click="prevent_close"
          >
            <div class="mb-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">
                  <%= if @view_only_mode do %>
                    View Member - {@current_member.email}
                  <% else %>
                    Edit Member - {@current_member.email}
                  <% end %>
                </h3>
                <button
                  phx-click="close_member_modal"
                  class="text-gray-400 hover:text-gray-600 focus:outline-none"
                >
                  <.icon name="hero-x-mark" class="h-6 w-6" />
                </button>
              </div>

              <div class="space-y-6">
                <%= if @view_only_mode do %>
                  <!-- View-only mode - show information without form -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">First name</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.first_name) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Last name</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.last_name) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Preferred name</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.preferred_name) ||
                          "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">T-shirt size</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.tshirt_size) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Phone number</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.phone_number) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Age</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.age) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Gender</label>
                      <div class="mt-1 text-sm text-gray-900">
                        <%= if @current_member.info && @current_member.info.gender do %>
                          <%= if @current_member.info.gender == :other do %>
                            {@current_member.info.gender_other || "Other"}
                          <% else %>
                            {@current_member.info.gender}
                          <% end %>
                        <% else %>
                          Not provided
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <h4 class="text-md font-semibold text-gray-900 mt-6 mb-4">Academic Information</h4>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">UIN</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.uin) || "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">
                        IEEE Membership Number
                      </label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.ieee_membership_number) ||
                          "Not provided"}
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Major</label>
                      <div class="mt-1 text-sm text-gray-900">
                        <%= if @current_member.info && @current_member.info.major do %>
                          <%= if @current_member.info.major == :other do %>
                            {@current_member.info.major_other || "Other"}
                          <% else %>
                            {@current_member.info.major}
                          <% end %>
                        <% else %>
                          Not provided
                        <% end %>
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">
                        International student
                      </label>
                      <div class="mt-1 text-sm text-gray-900">
                        <%= if @current_member.info && @current_member.info.international_student do %>
                          Yes
                          <%= if @current_member.info.international_country do %>
                            ({@current_member.info.international_country})
                          <% end %>
                        <% else %>
                          No
                        <% end %>
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Graduation year</label>
                      <div class="mt-1 text-sm text-gray-900">
                        {(@current_member.info && @current_member.info.graduation_year) ||
                          "Not provided"}
                      </div>
                    </div>
                  </div>

                  <div class="flex justify-between items-center mt-6">
                    <div class="flex space-x-3">
                      <.button
                        type="button"
                        phx-click="show_member"
                        phx-value-member_id={@current_member.id}
                        class="bg-indigo-600 hover:bg-indigo-700 text-white"
                      >
                        Edit Member
                      </.button>
                      <.button
                        type="button"
                        phx-click="close_member_modal"
                        class="bg-gray-300 hover:bg-gray-400 text-gray-800"
                      >
                        Close
                      </.button>
                    </div>
                  </div>
                <% else %>
                  <!-- Edit mode - show form -->
                  <.simple_form
                    for={@member_info_form}
                    id="member_info_form"
                    phx-submit="update_member_info"
                    phx-change="validate_member_info"
                  >
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <.input
                        field={@member_info_form[:first_name]}
                        label="First name *"
                        type="text"
                        required
                      />
                      <.input
                        field={@member_info_form[:last_name]}
                        label="Last name *"
                        type="text"
                        required
                      />
                      <.input
                        field={@member_info_form[:preferred_name]}
                        label="Preferred name"
                        type="text"
                      />
                      <.input
                        field={@member_info_form[:tshirt_size]}
                        label="T-shirt size *"
                        type="select"
                        prompt="Select a size"
                        options={Ecto.Enum.values(Members.Info, :tshirt_size)}
                        required
                      />
                      <.input
                        field={@member_info_form[:phone_number]}
                        label="Phone number"
                        type="tel"
                        placeholder="Ex. 979-845-7200"
                      />
                      <.input field={@member_info_form[:age]} label="Age" type="number" />
                      <.input
                        field={@member_info_form[:gender]}
                        label="Gender *"
                        type="select"
                        options={Ecto.Enum.values(Members.Info, :gender)}
                        required
                      />
                      <.input
                        :if={@member_info_form[:gender].value |> to_string == "Other"}
                        field={@member_info_form[:gender_other]}
                        label="Please specify"
                        type="text"
                      />
                    </div>

                    <h4 class="text-md font-semibold text-gray-900 mt-6 mb-4">
                      Academic Information
                    </h4>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <.input
                        field={@member_info_form[:uin]}
                        label="UIN *"
                        type="text"
                        placeholder="Ex. 731006823"
                        required
                      />
                      <.input
                        field={@member_info_form[:ieee_membership_number]}
                        label="IEEE Membership Number"
                        type="text"
                        placeholder="Ex. 97775577"
                      />
                      <.input
                        field={@member_info_form[:major]}
                        label="Major *"
                        type="select"
                        options={Ecto.Enum.values(Members.Info, :major)}
                        required
                      />
                      <.input
                        :if={@member_info_form[:major].value |> to_string() == "Other"}
                        field={@member_info_form[:major_other]}
                        label="Please specify *"
                        type="text"
                        required
                      />
                      <div class="flex justify-center items-center">
                        <.input
                          field={@member_info_form[:international_student]}
                          label="International student?"
                          type="checkbox"
                        />
                      </div>
                      <.input
                        :if={
                          Phoenix.HTML.Form.normalize_value(
                            "checkbox",
                            @member_info_form[:international_student].value
                          ) or
                            (
                              country = @member_info_form[:international_country].value
                              country != nil and country != ""
                            )
                        }
                        field={@member_info_form[:international_country]}
                        label="Country of origin *"
                        type="text"
                        required
                      />
                      <.input
                        field={@member_info_form[:graduation_year]}
                        label="Graduation year *"
                        type="number"
                        required
                      />
                    </div>

                    <div class="flex justify-between items-center mt-6">
                      <div class="flex space-x-3">
                        <.button type="submit" phx-disable-with="Saving...">
                          Save Changes
                        </.button>
                        <.button
                          type="button"
                          phx-click="close_member_modal"
                          class="bg-gray-300 hover:bg-gray-400 text-gray-800"
                        >
                          Cancel
                        </.button>
                      </div>
                    </div>
                  </.simple_form>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
