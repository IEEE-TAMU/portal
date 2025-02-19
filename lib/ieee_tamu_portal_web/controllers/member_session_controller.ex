defmodule IeeeTamuPortalWeb.MemberSessionController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Accounts
  alias IeeeTamuPortalWeb.MemberAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:member_return_to, ~p"/members/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"member" => member_params}, info) do
    %{"email" => email, "password" => password} = member_params

    if member = Accounts.get_member_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> MemberAuth.log_in_member(member, member_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/members/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> MemberAuth.log_out_member()
  end
end
