defmodule IeeeTamuPortalWeb.MemberMembershipRegistrationLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Repo, Settings.Setting, Members.Registration}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    current_member = socket.assigns.current_member

    # Get current registration year from settings
    registration_year_setting = Repo.get_by!(Setting, key: "registration_year")
    current_year = registration_year_setting.value

    # Look for existing registration for this member in the current year
    existing_registration = get_current_registration(current_member.id, current_year)

    {registration, status} =
      case existing_registration do
        nil ->
          # No registration exists, create one
          registration = create_registration_for_member(current_member)
          {registration, :new}

        registration ->
          # Registration exists, check if payment is complete
          registration_with_payment = Repo.preload(registration, :payment)

          if Registration.payment_complete?(registration_with_payment) do
            {registration_with_payment, :paid}
          else
            {registration_with_payment, :pending}
          end
      end

    socket =
      socket
      |> assign(:registration, registration)
      |> assign(:current_year, current_year)
      |> assign(:status, status)

    {:ok, socket}
  end

  @impl true
  def handle_event("copy_confirmation_code", %{"code" => _code}, socket) do
    # This will be handled by JavaScript on the client side
    {:noreply, put_flash(socket, :info, "Confirmation code copied to clipboard!")}
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
          <% :new -> %>
            <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-check-circle" class="w-5 h-5 text-green-600 mr-2" />
                <h3 class="text-green-800 font-medium">Registration Created Successfully!</h3>
              </div>
              <p class="text-green-700 mt-2">
                Your registration has been created. Please save your confirmation code for payment processing.
              </p>
            </div>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Registration Details</h3>

              <div>
                <label class="block text-sm font-medium text-gray-700">Confirmation Code</label>
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
                    phx-hook="CopyToClipboard"
                    id="copy-button"
                    class="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                    title="Copy to clipboard"
                  >
                    <.icon name="hero-clipboard" class="w-4 h-4" />
                    <.icon name="hero-check" class="w-4 h-4 hidden text-green-600" />
                  </button>
                </div>
              </div>
            </div>

            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div class="flex items-start">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-yellow-600 mr-2 mt-0.5" />
                <div>
                  <h3 class="text-yellow-800 font-medium">Payment Required</h3>
                  <p class="text-yellow-700 mt-1">
                    Your registration is pending payment. Please use the confirmation code above when making your payment.
                    Once payment is processed, your registration will be complete.
                  </p>
                </div>
              </div>
            </div>
          <% :pending -> %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-clock" class="w-5 h-5 text-yellow-600 mr-2" />
                <h3 class="text-yellow-800 font-medium">Payment Pending</h3>
              </div>
              <p class="text-yellow-700 mt-2">
                Your registration is awaiting payment processing.
              </p>
            </div>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Registration Details</h3>

              <div>
                <label class="block text-sm font-medium text-gray-700">Confirmation Code</label>
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
                    phx-hook="CopyToClipboard"
                    id="copy-button-pending"
                    class="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                    title="Copy to clipboard"
                  >
                    <.icon name="hero-clipboard" class="w-4 h-4" />
                    <.icon name="hero-check" class="w-4 h-4 hidden text-green-600" />
                  </button>
                </div>
              </div>
            </div>
          <% :paid -> %>
            <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-check-circle" class="w-5 h-5 text-green-600 mr-2" />
                <h3 class="text-green-800 font-medium">Registration Complete!</h3>
              </div>
              <p class="text-green-700 mt-2">
                Your registration and payment have been processed successfully.
              </p>
            </div>

            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Payment Details</h3>

              <%= if @registration.payment do %>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Amount Paid</label>
                    <input
                      type="text"
                      value={"$#{@registration.payment.amount}"}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700">
                      Payment Confirmation
                    </label>
                    <input
                      type="text"
                      value={@registration.payment.confirmation_code}
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
                    <label class="block text-sm font-medium text-gray-700">Contact Email</label>
                    <input
                      type="text"
                      value={@registration.payment.contact_email}
                      readonly
                      class="mt-1 w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900"
                    />
                  </div>
                </div>
              <% else %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <.icon name="hero-information-circle" class="w-5 h-5 text-blue-600 mr-2" />
                    <h3 class="text-blue-800 font-medium">Payment Override Applied</h3>
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
    """
  end

  defp get_current_registration(member_id, year) do
    year_int = String.to_integer(year)

    from(r in Registration,
      where: r.member_id == ^member_id and r.year == ^year_int,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp create_registration_for_member(member) do
    %Registration{}
    |> Registration.create_changeset(%{member_id: member.id}, member)
    |> Repo.insert!()
  end
end
