defmodule IeeeTamuPortalWeb.MemberMembershipRegistrationLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Settings, Members}

  @impl true
  def mount(_params, _session, socket) do
    current_member = socket.assigns.current_member

    # Get current registration year from settings
    current_year = Settings.get_registration_year!()

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

    status =
      if Members.Registration.payment_complete?(registration) do
        :paid
      else
        :pending
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
          <% :pending -> %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <.icon name="hero-clock" class="w-5 h-5 text-yellow-600 mr-2" />
                <h3 class="text-yellow-800 font-medium">Payment Pending</h3>
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
                    class="text-yellow-800 hover:underline"
                  >
                    info page <.icon name="hero-arrow-top-right-on-square" class="w-4 h-5" />.
                  </.link>
                  Once you've done so, reach out to an officer in the discord so they can mark your registration as paid.
                </p>
                <br />
                <p>
                  If you only want to sign up for branch membership, you can do so<.link
                    href="https://tamu.estore.flywire.com/institute-of-electrical-and-electronics-engineers/membership-dues"
                    class="text-yellow-800 hover:underline"
                  >
                    here <.icon name="hero-arrow-top-right-on-square" class="w-4 h-5" />.</.link> (make sure to enter the confirmation code below in the order form)
                </p>
              </div>
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
                    phx-hook=".CopyToClipboard"
                    id="copy-button-pending"
                    class="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                    title="Copy to clipboard"
                  >
                    <.icon name="hero-clipboard" class="w-4 h-4" />
                    <.icon name="hero-check" class="w-4 h-4 hidden text-green-600" />
                  </button>
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
end
