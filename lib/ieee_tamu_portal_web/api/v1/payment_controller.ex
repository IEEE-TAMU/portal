defmodule IeeeTamuPortalWeb.Api.V1.PaymentController do
  use IeeeTamuPortalWeb.ApiController, key_required: true

  alias IeeeTamuPortal.Members
  alias IeeeTamuPortalWeb.Api.V1.Schemas

  require Logger

  tags ["members"]

  operation :index,
    summary: "Get payment details",
    description: "Fetches the payment details for the authenticated user.",
    responses:
      [
        ok: {"Payment details", "application/json", Schemas.PaymentResponse}
      ] ++ List.flatten(@auth_responses)

  def index(conn, _params) do
    api_key = conn.assigns[:api_key]

    case Members.get_payments_by_api_key(api_key) do
      {:ok, payments} ->
        payments =
          payments
          |> Enum.map(&Schemas.Payment.from_struct/1)

        json(conn, payments)
    end
  end

  operation :show,
    summary: "Get payment details by ID",
    description: "Fetches the payment details for the authenticated user by id.",
    parameters: [
      %OpenApiSpex.Parameter{
        in: :path,
        name: "id",
        required: true,
        schema: Schemas.Payment.schema().properties[:id]
      }
    ],
    responses:
      [
        ok: {"Payment details", "application/json", Schemas.Payment},
        not_found: {"Payment not found", "application/json", Schemas.PaymentNotFoundResponse}
      ] ++ List.flatten(@auth_responses)

  def show(conn, %{"id" => id}) do
    api_key = conn.assigns[:api_key]

    case Members.get_payment_by_id_and_api_key(id, api_key) do
      {:ok, payment} ->
        json(conn, Schemas.Payment.from_struct(payment))

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Payment not found"})
        |> halt()
    end
  end

  operation :create,
    summary: "Create a new payment",
    description: "Creates a new payment for the authenticated user.",
    request_body: %OpenApiSpex.RequestBody{
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: Schemas.Payment.schema()
        }
      }
    },
    responses:
      [
        created: {"Payment created", "application/json", Schemas.Payment},
        forbidden: {"Forbidden", "application/json", Schemas.ForbiddenResponse}
      ] ++ List.flatten(@auth_responses)

  # TODO: make a better abstraction for admin only secured endpoints
  # built on the IeeeTamuPortalWeb.Auth.ApiAuth.admin_only() plug
  def create(conn, params) do
    conn =
      conn
      |> admin_only([])

    if conn.halted do
      conn
      # TODO: cleanup/refactor this?
    else
      {:ok, payment} = Members.create_payment(params)

      payment =
        case Members.associate_payment_with_registration(payment) do
          {:ok, payment} ->
            # Successfully associated payment with registration
            payment

          {:error, _reason} ->
            # Handle the error if association fails
            # For now, we just log it
            Logger.error("Failed to associate payment with registration: #{inspect(payment)}")
            payment
        end

      conn
      |> put_status(:created)
      |> json(Schemas.Payment.from_struct(payment))
    end
  end
end
