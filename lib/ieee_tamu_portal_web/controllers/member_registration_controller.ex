defmodule IeeeTamuPortalWeb.MemberRegistrationController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.{Repo, Settings.Setting, Members.Registration}
  import Ecto.Query

  def show(conn, _params) do
    current_member = conn.assigns.current_member

    # Get current registration year from settings
    registration_year_setting = Repo.get_by!(Setting, key: "registration_year")
    current_year = registration_year_setting.value

    # Look for existing registration for this member in the current year
    existing_registration = get_current_registration(current_member.id, current_year)

    case existing_registration do
      nil ->
        # No registration exists, create one
        registration = create_registration_for_member(current_member)
        render_registration_page(conn, registration, current_year, :new)

      registration ->
        # Registration exists, check if payment is complete
        registration_with_payment = Repo.preload(registration, :payment)

        if Registration.payment_complete?(registration_with_payment) do
          render_registration_page(conn, registration_with_payment, current_year, :paid)
        else
          render_registration_page(conn, registration_with_payment, current_year, :pending)
        end
    end
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

  defp render_registration_page(conn, registration, current_year, status) do
    render(conn, :show,
      registration: registration,
      current_year: current_year,
      status: status
    )
  end
end
