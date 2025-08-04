defmodule IeeeTamuPortalWeb.TestTableLive do
  use IeeeTamuPortalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    dbg(params)
    {members, meta} = IeeeTamuPortal.Accounts.Member.list_members(params)
    {:noreply, assign(socket, members: members, meta: meta)}
  end

  @impl true
  def handle_event("filter", %{"meta" => meta_params}, socket) do
    # Use Flop's built-in parameter handling
    {:noreply, push_patch(socket, to: ~p"/admin/test_table?#{meta_params}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/test_table")}
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
          |> Phoenix.LiveView.put_flash(:error, "Failed to update payment status for #{member.email}")

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
        action = case get_payment_status(updated_member) do
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
          |> Phoenix.LiveView.put_flash(:error, "Failed to toggle payment override for #{member.email}")

        {:noreply, socket}
    end
  end

  # Helper function to mark member as paid
  defp mark_member_as_paid(member) do
    alias IeeeTamuPortal.{Members, Settings}

    current_year = Settings.get_registration_year!()

    case Members.toggle_payment_override(member, current_year) do
      {:ok, updated_registration} ->
        # Update the member with the new registration data
        updated_registrations = case member.registrations do
          [] -> [updated_registration]
          [_old_reg] -> [updated_registration]
          multiple -> multiple # shouldn't happen with our query
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
        >
          <div class="flex items-end justify-between gap-3">
            <div class="flex-1">
              <Flop.Phoenix.filter_fields
                :let={i}
                form={to_form(@meta)}
                fields={[
                  email: [label: "Filter by Email", type: "text", placeholder: "Enter email to search...", op: :like]
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
            <div>
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
            page_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}
            current_page_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-indigo-600 rounded-md"]}
            page_list_attrs={[class: "flex space-x-1"]}
            disabled_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-white border border-gray-300 cursor-default rounded-md"]}
            class="flex items-center space-x-2"
          >
            <:previous attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}>
              Previous
            </:previous>
            <:next attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}>
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
                  thead_th_attrs: [class: "px-3 py-3.5 text-left text-sm font-semibold text-gray-900", scope: "col"],
                  tbody_td_attrs: [class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"],
                  tbody_tr_attrs: [class: "hover:bg-gray-50"],
                  no_results_content: nil
                ]}
              >
                <:col
                  :let={member}
                  label="Email"
                  field={:email}
                  thead_th_attrs={[class: "py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6", scope: "col"]}
                  tbody_td_attrs={[class: "whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"]}
                >
                  {member.email}
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
                  tbody_td_attrs={[class: "whitespace-nowrap px-3 py-4 text-sm text-gray-500"]}
                >
                  <%= case get_payment_status(member) do %>
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
                  <%= Calendar.strftime(member.inserted_at, "%b %d, %Y") %>
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
            page_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}
            current_page_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-indigo-600 rounded-md"]}
            page_list_attrs={[class: "flex space-x-1"]}
            disabled_link_attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-white border border-gray-300 cursor-default rounded-md"]}
            class="flex items-center space-x-2"
          >
            <:previous attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}>
              Previous
            </:previous>
            <:next attrs={[class: "relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50"]}>
              Next
            </:next>
          </Flop.Phoenix.pagination>
        </div>
      </div>
    </div>
    """
  end
end
