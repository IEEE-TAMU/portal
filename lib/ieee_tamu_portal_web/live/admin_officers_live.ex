defmodule IeeeTamuPortalWeb.AdminOfficersLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Accounts, Settings}
  alias IeeeTamuPortal.Accounts.Member

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "IEEE Admin - Officers")
     |> assign(:year, Settings.get_registration_year!())
     |> assign_member_lists()}
  end

  @impl true
  def handle_event("grant", %{"email" => email, "role" => role}, socket) do
    email = String.trim(email)

    case Accounts.get_member_by_email(email) do
      nil ->
        {:noreply, put_flash(socket, :error, "No member account found with the email #{email}.")}

      member ->
        {:noreply, apply_role_change(socket, member, parse_role(role))}
    end
  end

  def handle_event("update_role", %{"id" => id, "role" => role}, socket) do
    case get_member(id) do
      nil -> {:noreply, put_flash(socket, :error, "Member not found.")}
      member -> {:noreply, apply_role_change(socket, member, parse_role(role))}
    end
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    case get_member(id) do
      nil -> {:noreply, put_flash(socket, :error, "Member not found.")}
      member -> {:noreply, apply_role_change(socket, member, :member)}
    end
  end

  defp get_member(id) do
    case parse_id(id) do
      nil -> nil
      parsed_id -> Accounts.get_member(parsed_id)
    end
  end

  defp assign_member_lists(socket) do
    assign(socket,
      privileged_members: Accounts.list_privileged_members_with_status(socket.assigns.year),
      missing_ieee_members: Accounts.list_privileged_members_missing_ieee_number()
    )
  end

  defp apply_role_change(socket, member, role) do
    current_member = socket.assigns.current_member

    cond do
      is_nil(role) ->
        put_flash(socket, :error, "Unknown role.")

      role != :member and is_nil(member.confirmed_at) ->
        put_flash(
          socket,
          :error,
          "#{member.email} must confirm their email address before they can be an officer."
        )

      member.id == current_member.id and role != :admin ->
        put_flash(socket, :error, "You cannot remove your own admin access.")

      member.role == :admin and role != :admin and Accounts.count_admins() <= 1 ->
        put_flash(socket, :error, "At least one admin must remain.")

      member.role == role ->
        put_flash(
          socket,
          :info,
          "#{member.email} already has the #{Member.role_label(role)} role."
        )

      true ->
        case Accounts.update_member_role(member, role) do
          {:ok, updated_member} ->
            socket
            |> assign_member_lists()
            |> put_flash(
              :info,
              "#{updated_member.email} is now #{Member.role_label(updated_member.role)}."
            )

          {:error, _changeset} ->
            put_flash(socket, :error, "Could not update #{member.email}'s role.")
        end
    end
  end

  defp parse_role("admin"), do: :admin
  defp parse_role("officer"), do: :officer
  defp parse_role("member"), do: :member
  defp parse_role(_), do: nil

  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp parse_id(_), do: nil

  defp member_name(%Member{info: %{preferred_name: name}}) when is_binary(name) and name != "",
    do: name

  defp member_name(%Member{info: %{first_name: first, last_name: last}})
       when is_binary(first) and is_binary(last),
       do: "#{first} #{last}"

  defp member_name(_member), do: "Not provided"

  defp role_badge_class(:admin), do: "bg-purple-100 text-purple-800"
  defp role_badge_class(:officer), do: "bg-blue-100 text-blue-800"
  defp role_badge_class(_), do: "bg-gray-100 text-gray-700"

  # The registration list is already scoped to the current year by the query,
  # so the first entry is sufficient.
  defp current_registration(member), do: List.first(member.registrations || [])

  defp payment_status(member) do
    case current_registration(member) do
      nil -> nil
      registration -> registration.payment_status
    end
  end

  defp payment_label(nil), do: "Not registered"
  defp payment_label(:override), do: "Override"
  defp payment_label(:paid), do: "Paid"
  defp payment_label(:pending), do: "Pending"

  defp payment_badge_class(nil), do: "bg-gray-100 text-gray-700"
  defp payment_badge_class(:override), do: "bg-emerald-100 text-emerald-800"
  defp payment_badge_class(:paid), do: "bg-green-100 text-green-800"
  defp payment_badge_class(:pending), do: "bg-amber-100 text-amber-800"

  defp discord_account(member) do
    Enum.find(member.secondary_auth_methods || [], &(&1.provider == :discord))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900">Officer Management</h1>
      <p class="text-gray-600 mt-2">
        Officers can access the admin panel. Admins can additionally grant and revoke
        officer and admin access for other members.
      </p>
      <p class="text-sm text-gray-500 mt-2">
        Payment status "Override" means an admin manually verified that the officer's
        global IEEE membership is currently active.
      </p>
    </div>

    <div class="bg-white rounded-lg shadow p-6 mb-8">
      <h2 class="text-xl font-semibold text-gray-900 mb-1">Grant admin panel access</h2>
      <p class="text-sm text-gray-600 mb-4">
        Enter the email address of a confirmed member account.
      </p>

      <form
        id="grant-officer-form"
        phx-submit="grant"
        class="flex flex-col sm:flex-row gap-3 sm:items-end"
      >
        <div class="flex-1">
          <label for="officer-email" class="block text-sm font-medium text-gray-700 mb-1">
            Member email
          </label>
          <input
            id="officer-email"
            type="email"
            name="email"
            required
            placeholder="member@tamu.edu"
            class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:ring-indigo-500"
          />
        </div>
        <div>
          <label for="officer-role" class="block text-sm font-medium text-gray-700 mb-1">
            Role
          </label>
          <select
            id="officer-role"
            name="role"
            class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-indigo-500 focus:ring-indigo-500"
          >
            <option value="officer">Officer</option>
            <option value="admin">Admin</option>
          </select>
        </div>
        <button
          type="submit"
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
        >
          Grant access
        </button>
      </form>
    </div>

    <section
      id="missing-ieee-members"
      class="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-8"
    >
      <h2 class="text-xl font-semibold text-amber-900 mb-1">
        Officers missing an IEEE membership number
      </h2>
      <p class="text-sm text-amber-800 mb-4">
        Officers are required to hold global IEEE membership. This is separate from
        local branch dues. Update the number from the member's profile in the directory.
      </p>

      <%= if @missing_ieee_members == [] do %>
        <p class="rounded-md bg-green-50 px-3 py-2 text-sm text-green-800">
          All officers and admins have an IEEE membership number.
        </p>
      <% else %>
        <p class="mb-3 text-sm font-medium text-amber-900">
          {length(@missing_ieee_members)} account(s) need an IEEE membership number.
        </p>

        <ul class="divide-y divide-amber-200 overflow-hidden rounded-md border border-amber-200 bg-white">
          <li
            :for={member <- @missing_ieee_members}
            class="flex flex-wrap items-center justify-between gap-3 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-gray-900">{member_name(member)}</p>
              <p class="truncate text-sm text-gray-600">{member.email}</p>
            </div>
            <span class={[
              "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
              role_badge_class(member.role)
            ]}>
              {Member.role_label(member.role)}
            </span>
          </li>
        </ul>

        <div class="mt-4">
          <.link
            navigate={~p"/admin/members"}
            class="text-sm font-medium text-amber-900 underline hover:text-amber-700"
          >
            Open the member directory to update numbers
          </.link>
        </div>
      <% end %>
    </section>

    <div class="bg-white rounded-lg shadow overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200">
        <h2 class="text-xl font-semibold text-gray-900">Current officers and admins</h2>
      </div>

      <%= if @privileged_members == [] do %>
        <p class="px-6 py-8 text-sm text-gray-600">No officers or admins yet.</p>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                  Member
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                  Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                  Payment {@year}
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
                  Discord
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200 bg-white">
              <tr :for={member <- @privileged_members}>
                <td class="px-6 py-4">
                  <div class="text-sm font-medium text-gray-900">
                    {member_name(member)}
                    <span :if={member.id == @current_member.id} class="text-gray-500">(you)</span>
                  </div>
                  <div class="text-sm text-gray-600">{member.email}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                    role_badge_class(member.role)
                  ]}>
                    {Member.role_label(member.role)}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                    payment_badge_class(payment_status(member))
                  ]}>
                    {payment_label(payment_status(member))}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <%= if discord = discord_account(member) do %>
                    <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                      Linked
                    </span>
                    <div class="mt-1 text-xs text-gray-500">
                      {discord.preferred_username || discord.email || "Connected"}
                    </div>
                  <% else %>
                    <span class="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-600">
                      Not linked
                    </span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm">
                  <%= if member.id == @current_member.id do %>
                    <span class="text-gray-500">Your own access cannot be changed here.</span>
                  <% else %>
                    <button
                      :if={member.role == :officer}
                      type="button"
                      phx-click="update_role"
                      phx-value-id={member.id}
                      phx-value-role="admin"
                      class="rounded-md px-2.5 py-1.5 font-medium text-purple-700 hover:bg-purple-50"
                    >
                      Make admin
                    </button>
                    <button
                      :if={member.role == :admin}
                      type="button"
                      phx-click="update_role"
                      phx-value-id={member.id}
                      phx-value-role="officer"
                      class="rounded-md px-2.5 py-1.5 font-medium text-blue-700 hover:bg-blue-50"
                    >
                      Make officer
                    </button>
                    <button
                      type="button"
                      phx-click="revoke"
                      phx-value-id={member.id}
                      data-confirm="Remove admin panel access from this member?"
                      class="rounded-md px-2.5 py-1.5 font-medium text-rose-700 hover:bg-rose-50"
                    >
                      Revoke
                    </button>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
