defmodule IeeeTamuPortalWeb.Api.V1.PaymentController do
  use IeeeTamuPortalWeb.ApiController

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortalWeb.Api.V1.Schemas

  require Logger

  tags ["members"]

  api_operation :index,
    summary: "Get payment details",
    description: "Fetches the payment details for the authenticated user.",
    responses: [
      ok: {"Payment details", "application/json", Schemas.PaymentResponse}
    ] do
    fn conn, _params, api_key ->
      case Members.get_payments_by_api_key(api_key) do
        {:ok, payments} ->
          payments =
            payments
            |> Enum.map(&Schemas.Payment.from_struct/1)

          json(conn, payments)
      end
    end
  end

  api_operation :show,
    summary: "Get payment details by Order ID",
    description: "Fetches the payment details for the authenticated user by Flywire order ID.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :path,
        name: "id",
        required: true,
        schema: Schemas.Payment.schema().properties[:id]
      }
    ],
    responses: [
      ok: {"Payment details", "application/json", Schemas.Payment},
      not_found: {"Payment not found", "application/json", Schemas.PaymentNotFoundResponse}
    ] do
    fn conn, params, api_key ->
      case Members.get_payment_by_id_and_api_key(params["id"], api_key) do
        {:ok, payment} ->
          json(conn, Schemas.Payment.from_struct(payment))

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(Schemas.PaymentNotFoundResponse.default())
          |> halt()
      end
    end
  end

  admin_operation :create,
    summary: "Create a new payment",
    description: "Creates a new payment for the authenticated user. Requires admin privileges.",
    request_body: %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: Schemas.Payment.schema()
        }
      }
    },
    responses: [
      created: {"Payment created", "application/json", Schemas.Payment}
    ] do
    fn conn, params, _api_key ->
      case Members.create_payment(params) do
        {:ok, payment} ->
          payment =
            case Members.associate_payment_with_registration(payment) do
              {:ok, payment} ->
                payment

              {:error, _reason} ->
                Logger.warning(
                  "Failed to associate payment with registration: #{inspect(payment)}"
                )

                payment
            end

          conn
          |> put_status(:created)
          |> json(Schemas.Payment.from_struct(payment))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: changeset_errors(changeset)})
      end
    end
  end
end
