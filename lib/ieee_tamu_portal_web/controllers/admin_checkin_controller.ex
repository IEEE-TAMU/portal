defmodule IeeeTamuPortalWeb.AdminCheckinController do
  use IeeeTamuPortalWeb, :controller

  alias IeeeTamuPortal.Members.EventCheckin

  # GET /admin/check-in?member_id=<id>
  def create(conn, %{"member_id" => member_id}) do
    parsed_id = parse_member_id(member_id)

    case EventCheckin.insert_for_member_id(parsed_id) do
      {:ok, _checkin} ->
        Phoenix.PubSub.broadcast(
          IeeeTamuPortal.PubSub,
          "checkins",
          {:member_checked_in, parsed_id}
        )

        conn |> put_status(:created) |> text("checked-in")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_error"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_member_param"})
  end

  defp parse_member_id(member_id) when is_binary(member_id) do
    case Integer.parse(member_id) do
      {int, _} -> int
      :error -> member_id
    end
  end

  defp parse_member_id(member_id), do: member_id
end
