defmodule IeeeTamuPortalWeb.Api.V1.PingController do
  use IeeeTamuPortalWeb.ApiController

  # alias IeeeTamuPortal.Members
  # # TODO: move logic to Members context
  # alias IeeeTamuPortal.Repo

  tags ["demo"]

  operation :show,
    summary: "Ping the API",
    description: "Returns a simple 'pong' response to check if the API is reachable.",
    responses:
      [
        ok: {"Pong response", "application/json", IeeeTamuPortalWeb.Api.V1.Schemas.PingResponse}
      ] ++ List.flatten(@auth_responses)

  def show(conn, _params) do
    json(conn, %{message: "pong"})
  end

  # def token_info(conn, _params) do
  #   api_key = conn.assigns[:api_key]

  #   response =
  #     case api_key.context do
  #       :admin ->
  #         %{
  #           context: "admin",
  #           last_used_at: api_key.last_used_at
  #         }

  #       :member ->
  #         %{
  #           context: "member",
  #           member_id: api_key.member_id,
  #           last_used_at: api_key.last_used_at
  #         }
  #     end

  #   json(conn, response)
  # end

  # def create_payment(conn, %{"payment" => payment_params}) do
  #   alias Members.{Registration, Payment}

  #   # Look for registration by confirmation code
  #   import Ecto.Query

  #   registration_with_payment =
  #     Registration
  #     |> where([r], r.confirmation_code == ^payment_params["confirmation_code"])
  #     |> join(:left, [r], p in assoc(r, :payment))
  #     |> preload([_r, p], payment: p)
  #     |> Repo.one()

  #   case registration_with_payment do
  #     # No registration found, save payment without association
  #     nil ->
  #       case Members.create_payment(payment_params) do
  #         {:ok, payment} ->
  #           conn
  #           |> put_status(:accepted)
  #           |> json(%{
  #             status: "partial_success",
  #             message: "Payment created but no matching registration found",
  #             payment_id: payment.id,
  #             warning:
  #               "Confirmation code '#{payment_params["confirmation_code"]}' does not match any registration"
  #           })

  #         {:error, changeset} ->
  #           conn
  #           |> put_status(:unprocessable_entity)
  #           |> json(%{
  #             status: "error",
  #             message: "Failed to create payment",
  #             errors: format_changeset_errors(changeset)
  #           })
  #       end

  #     # If a registration is found with no payment
  #     %Registration{payment: nil} = registration ->
  #       # Registration found, create payment with association
  #       dbg(registration)

  #       payment_changeset =
  #         Ecto.build_assoc(registration, :payment)
  #         |> Payment.changeset(payment_params)

  #       case Repo.insert(payment_changeset) do
  #         {:ok, payment} ->
  #           conn
  #           |> put_status(:created)
  #           |> json(%{
  #             status: "success",
  #             message: "Payment created successfully",
  #             payment_id: payment.id,
  #             registration_id: registration.id
  #           })

  #         {:error, changeset} ->
  #           conn
  #           |> put_status(:unprocessable_entity)
  #           |> json(%{
  #             status: "error",
  #             message: "Failed to create payment",
  #             errors: format_changeset_errors(changeset)
  #           })
  #       end

  #     # If a registration is found with an existing payment,
  #     # add the new entry but do not create the association again
  #     %Registration{payment: %Payment{} = _existing_payment} ->
  #       {confirmation_code, payment_params} = Map.pop(payment_params, "confirmation_code")

  #       case Members.create_payment(payment_params) do
  #         {:ok, payment} ->
  #           conn
  #           |> put_status(:accepted)
  #           |> json(%{
  #             status: "partial_success",
  #             message: "Payment created but already associated with a registration",
  #             payment_id: payment.id,
  #             warning:
  #               "Confirmation code '#{confirmation_code}' already has an associated payment"
  #           })

  #         {:error, changeset} ->
  #           conn
  #           |> put_status(:unprocessable_entity)
  #           |> json(%{
  #             status: "error",
  #             message: "Failed to create payment",
  #             errors: format_changeset_errors(changeset)
  #           })
  #       end
  #   end
  # end

  # # Handle missing payment parameter
  # def create_payment(conn, _params) do
  #   conn
  #   |> put_status(:bad_request)
  #   |> json(%{
  #     status: "error",
  #     message: "Missing 'payment' parameter in request body"
  #   })
  # end

  # # Helper function to format changeset errors
  # defp format_changeset_errors(changeset) do
  #   Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
  #     Enum.reduce(opts, msg, fn {key, value}, acc ->
  #       String.replace(acc, "%{#{key}}", to_string(value))
  #     end)
  #   end)
  # end
end
