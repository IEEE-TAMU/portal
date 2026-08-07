defmodule IeeeTamuPortalWeb.AdminVerificationLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Accounts, Members, Settings}
  import IeeeTamuPortalWeb.PaginationComponents

  @impl true
  def mount(_params, _session, socket) do
    current_year = Settings.get_registration_year!()

    {:ok,
     assign(socket,
       page_title: "IEEE Admin - Verification",
       year: current_year
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    current_year = socket.assigns.year
    params = Map.put_new(params, "page_size", "10")
    {members, meta} = Accounts.list_members_pending_verification(current_year, params)

    {:noreply,
     assign(socket,
       members: members,
       meta: meta,
       filter_params: params
     )}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/verification?#{%{"filters" => filter_params}}")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/verification")}
  end

  @impl true
  def handle_event("approve", %{"member_id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    current_year = socket.assigns.year

    member = Enum.find(socket.assigns.members, &(&1.id == member_id))

    case Members.toggle_payment_override(member, current_year) do
      {:ok, _updated_registration} ->
        params = Map.get(socket.assigns, :filter_params, %{})
        {members, meta} = Accounts.list_members_pending_verification(current_year, params)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:meta, meta)
         |> put_flash(:info, "Payment override approved for #{member.email}")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to approve payment override for #{member.email}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      IEEE Membership Verification
      <:subtitle>
        Members who have provided their IEEE membership number but have not yet been verified for {@year}.
      </:subtitle>
    </.header>

    <div class="mt-6">
      <.filter_form meta={@meta} path={~p"/admin/verification"} />
    </div>

    <div class="mt-6 flex items-center justify-between">
      <.page_size_selector meta={@meta} path={~p"/admin/verification"} />
      <.pagination meta={@meta} path={~p"/admin/verification"} />
    </div>

    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
            <%= if @meta.total_count == 0 do %>
              <.empty_state
                icon="hero-check-badge"
                title="All caught up!"
                subtitle={"No members are currently pending IEEE membership verification for #{@year}."}
              />
            <% else %>
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Member
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                    >
                      IEEE #
                    </th>
                    <th
                      scope="col"
                      class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                    >
                      Validate
                    </th>
                    <th
                      scope="col"
                      class="relative py-3.5 pl-3 pr-4 sm:pr-6"
                    >
                      <span class="sr-only">Approve</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for member <- @members do %>
                    <tr class="hover:bg-gray-50">
                      <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                        <%= if member.info && member.info.first_name && member.info.last_name do %>
                          <%= if member.info.preferred_name && String.trim(member.info.preferred_name) != "" do %>
                            {member.info.preferred_name} {member.info.last_name}
                          <% else %>
                            {member.info.first_name} {member.info.last_name}
                          <% end %>
                          <div class="text-xs text-gray-500">{member.email}</div>
                        <% else %>
                          {member.email}
                        <% end %>
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 font-mono">
                        {member.info.ieee_membership_number}
                      </td>
                      <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <form
                          action="https://services24.ieee.org/membership-validator.html"
                          method="post"
                          target="_blank"
                          rel="noopener"
                          class="inline"
                        >
                          <input
                            type="hidden"
                            name="customerId"
                            value={member.info.ieee_membership_number}
                          />
                          <button
                            type="submit"
                            class="text-indigo-600 hover:text-indigo-900 text-xs font-medium"
                            title="Open IEEE Membership Validator in a new tab"
                          >
                            Validate
                          </button>
                        </form>
                      </td>
                      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <button
                          phx-click="approve"
                          phx-value-member_id={member.id}
                          class="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-xs font-medium text-green-800 hover:bg-green-200 cursor-pointer transition-colors"
                        >
                          Approve
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-6 flex items-center justify-between">
      <.page_size_selector meta={@meta} path={~p"/admin/verification"} />
      <.pagination meta={@meta} path={~p"/admin/verification"} />
    </div>
    """
  end
end
