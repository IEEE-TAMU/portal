defmodule IeeeTamuPortalWeb.MemberSettingsLive do
  use IeeeTamuPortalWeb, :live_view

  alias IeeeTamuPortal.{Accounts, Members, Repo}

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Personal information
    </.header>

    <div class="space-y-12">
      <div>
        <.simple_form
          for={@info_form}
          id="info_form"
          phx-submit="update_info"
          phx-change="validate_info"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <.input field={@info_form[:first_name]} label="First name *" type="text" required />
            <.input field={@info_form[:last_name]} label="Last name *" type="text" required />
            <.input
              field={@info_form[:preferred_name]}
              label="Preferred name"
              type="text"
              placeholder={@info_form[:first_name].value}
            />
            <.input
              field={@info_form[:tshirt_size]}
              label="T-shirt size *"
              type="select"
              prompt="Select a size"
              options={Ecto.Enum.values(Members.Info, :tshirt_size)}
              required
            />
            <.input
              field={@info_form[:phone_number]}
              label="Phone number"
              type="tel"
              placeholder="Ex. 979-845-7200"
              phx-hook="PhoneNumber"
            />
            <.input field={@info_form[:age]} label="Age" type="number" />
            <.input
              field={@info_form[:gender]}
              label="Gender *"
              type="select"
              options={Ecto.Enum.values(Members.Info, :gender)}
              required
            />
            <.input
              :if={@info_form[:gender].value |> to_string == "Other"}
              field={@info_form[:gender_other]}
              label="Please specify"
              type="text"
            />
          </div>
          <.header class="text-center mt-4">Academic information</.header>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <.input
              field={@info_form[:uin]}
              label="UIN *"
              type="text"
              placeholder="Ex. 731006823"
              required
            />
            <.input
              field={@info_form[:ieee_membership_number]}
              label="IEEE Membership Number"
              type="text"
              placeholder="Ex. 97775577"
            />
            <.input
              field={@info_form[:major]}
              label="Major *"
              type="select"
              options={Ecto.Enum.values(Members.Info, :major)}
              required
            />
            <.input
              :if={@info_form[:major].value |> to_string() == "Other"}
              field={@info_form[:major_other]}
              label="Please specify *"
              type="text"
              phx-hook="AutoUpcase"
              required
            />
            <div class="flex justify-center items-center">
              <.input
                field={@info_form[:international_student]}
                label="International student?"
                type="checkbox"
              />
            </div>
            <.input
              :if={
                Phoenix.HTML.Form.normalize_value(
                  "checkbox",
                  @info_form[:international_student].value
                ) or
                  (
                    country = @info_form[:international_country].value
                    country != nil and country != ""
                  )
              }
              field={@info_form[:international_country]}
              label="Country of origin *"
              type="text"
              required
            />
            <.input
              field={@info_form[:graduation_year]}
              label="Graduation year *"
              type="number"
              required
            />
          </div>
          <:actions>
            <.button phx-disable-with="Saving...">Save</.button>
          </:actions>
        </.simple_form>
      </div>
      <.header class="text-center">
        Change password
      </.header>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/members/login?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_member_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    member =
      socket.assigns.current_member
      |> Repo.preload(:info)

    info_changeset = Members.change_member_info(member.info)
    password_changeset = Accounts.change_member_password(member)

    socket =
      socket
      |> assign(:current_member, member)
      |> assign(:current_password, nil)
      |> assign(:current_email, member.email)
      |> assign(:info_form, to_form(info_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_info", params, socket) do
    %{"info" => info_params} = params
    info = socket.assigns.current_member.info

    info_form =
      info
      |> Members.change_member_info(info_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, info_form: info_form)}
  end

  def handle_event("update_info", params, socket) do
    %{"info" => info_params} = params
    member = socket.assigns.current_member

    update_or_create_info = fn
      %Members.Info{} = info -> Members.update_member_info(info, info_params)
      nil -> Members.create_member_info(member, info_params)
    end

    case update_or_create_info.(member.info) do
      {:ok, info} ->
        member = %Accounts.Member{member | info: info}

        info_form =
          info
          |> Members.change_member_info()
          |> to_form()

        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "Your information has been updated.")
          |> assign(:current_member, member)
          |> assign(:info_form, info_form)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, info_form: to_form(changeset))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "member" => member_params} = params

    password_form =
      socket.assigns.current_member
      |> Accounts.change_member_password(member_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "member" => member_params} = params
    member = socket.assigns.current_member

    case Accounts.update_member_password(member, password, member_params) do
      {:ok, member} ->
        password_form =
          member
          |> Accounts.change_member_password(member_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
